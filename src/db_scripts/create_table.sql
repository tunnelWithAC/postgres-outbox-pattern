CREATE TABLE platform.schema_changes (
    id          bigserial PRIMARY KEY,
    event_data  jsonb NOT NULL,
    created_at  timestamptz DEFAULT now(),
    processed   boolean DEFAULT false,
    processed_at timestamptz
);

-- Index for efficient polling if LISTEN/NOTIFY goes down
CREATE INDEX idx_unprocessed ON platform.schema_changes (processed, created_at) 
WHERE NOT processed;
