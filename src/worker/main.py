import psycopg2
import json

# Connect directly to Postgres (not through a connection pooler)
conn = psycopg2.connect(DATABASE_URL)
conn.autocommit = True
cur = conn.cursor()

# Start listening
cur.execute("LISTEN schema_changed;")

while True:
    # This blocks until a notification arrives
    conn.poll()
    while conn.notifies:
        notify = conn.notifies.pop(0)
        event_id = notify.payload
        
        # Fetch the full event from the outbox
        cur.execute("""
            UPDATE platform.schema_changes 
            SET processed = true, processed_at = now()
            WHERE event_data->>'event_id' = %s AND NOT processed
            RETURNING event_data
        """, (event_id,))
        
        if row := cur.fetchone():
            process_schema_change(row[0])
