
-- 1. Create base tables
CREATE TABLE IF NOT EXISTS platform.outbox (
    id          bigserial PRIMARY KEY,
    event_type  text NOT NULL, -- e.g., 'INSERT'
    payload     jsonb NOT NULL,
    created_at  timestamptz DEFAULT now()
);
CREATE TABLE IF NOT EXISTS platform.cars (
  brand VARCHAR(255),
  model VARCHAR(255),
  year INT
);

-- 2. Create Trigger
CREATE OR REPLACE FUNCTION log_car_to_outbox() 
RETURNS trigger AS $$
BEGIN
    INSERT INTO platform.outbox (event_type, payload)
    VALUES (
        TG_OP,             -- Automatically holds 'INSERT', 'UPDATE', etc.
        row_to_json(NEW)::jsonb
    );
    
    -- Optional: Notify listeners for real-time processing
    PERFORM pg_notify('new_car_event', lastval()::text);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Attach trigger to table
CREATE TRIGGER trigger_cars_outbox
AFTER INSERT ON platform.cars
FOR EACH ROW
EXECUTE FUNCTION log_car_to_outbox();