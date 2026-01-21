-- 1. Create table to track schema changes
CREATE TABLE IF NOT EXISTS platform.schema_changes (
    id          bigserial PRIMARY KEY,
    event_data  jsonb NOT NULL,
    created_at  timestamptz DEFAULT now(),
    processed   boolean DEFAULT false,
    processed_at timestamptz
);

-- Index for efficient polling if LISTEN/NOTIFY goes down
CREATE INDEX idx_unprocessed ON platform.schema_changes (processed, created_at) 
WHERE NOT processed;

-- 2. Minimal trigger function: log and notify
CREATE FUNCTION platform.log_and_notify() RETURNS event_trigger AS $$
DECLARE
    rec record;
    payload jsonb;
BEGIN
    -- pg_event_trigger_ddl_commands() gives us metadata about what just happened
    FOR rec IN SELECT * FROM pg_event_trigger_ddl_commands() LOOP
        payload := jsonb_build_object(
            'event_id', gen_random_uuid(),
            'command', rec.command_tag,
            'object_identity', rec.object_identity,
            'schema_name', rec.schema_name,
            'timestamp', now()
        );
        
        -- Write to our durable outbox
        INSERT INTO platform.schema_changes (event_data) VALUES (payload);
        
        -- Notify any listening workers
        PERFORM pg_notify('schema_changed', payload->>'event_id');
    END LOOP;
END;
$$ LANGUAGE plpgsql;


-- 3. Capture every schema change
CREATE EVENT TRIGGER capture_ddl_changes
    ON ddl_command_end
    WHEN TAG IN ('CREATE TABLE', 'ALTER TABLE', 'DROP TABLE')
    EXECUTE FUNCTION platform.log_and_notify();
