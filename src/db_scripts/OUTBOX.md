To transition from tracking schema changes (DDL) to tracking row data changes (DML), you need to use a **Row-Level Trigger**.

In PostgreSQL, **Event Triggers** are global and capture structural changes (like `CREATE TABLE`), whereas **Regular Triggers** sit on a specific table and capture data changes (like `INSERT`).

Here is the implementation to move data from `cars` to an `outbox` table.

---

### 1. Create the Outbox Table

First, define a table to store the captured row data. Using `jsonb` makes it flexible if you ever add columns to the `cars` table.

```sql
CREATE TABLE IF NOT EXISTS outbox (
    id          bigserial PRIMARY KEY,
    event_type  text NOT NULL, -- e.g., 'INSERT'
    payload     jsonb NOT NULL,
    created_at  timestamptz DEFAULT now()
);

```

### 2. Create the Trigger Function

This function converts the new row (`NEW`) into JSON and inserts it into the outbox. Note that it returns `trigger` instead of `event_trigger`.

```sql
CREATE OR REPLACE FUNCTION log_car_to_outbox() 
RETURNS trigger AS $$
BEGIN
    INSERT INTO outbox (event_type, payload)
    VALUES (
        TG_OP,             -- Automatically holds 'INSERT', 'UPDATE', etc.
        row_to_json(NEW)::jsonb
    );
    
    -- Optional: Notify listeners for real-time processing
    PERFORM pg_notify('new_car_event', lastval()::text);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

```

### 3. Attach the Trigger to the Cars Table

Now, link the function to the `cars` table. This will fire every time a row is inserted.

```sql
CREATE TRIGGER trigger_cars_outbox
AFTER INSERT ON cars
FOR EACH ROW
EXECUTE FUNCTION log_car_to_outbox();

```

---

### Key Differences from your DDL Script

| Feature | Your DDL Script (Event Trigger) | This Data Script (DML Trigger) |
| --- | --- | --- |
| **Scope** | Database-wide (Global) | Table-specific (`cars`) |
| **Return Type** | `RETURNS event_trigger` | `RETURNS trigger` |
| **Data Access** | Uses `pg_event_trigger_ddl_commands()` | Uses the `NEW` and `OLD` records |
| **Timing** | `ON ddl_command_end` | `AFTER INSERT` |

### Why use "AFTER INSERT"?

Using `AFTER INSERT` ensures that the outbox entry is only created if the car row was successfully written to the database. Because both operations happen within the same transaction, if the `INSERT` into the `cars` table fails, nothing is written to the `outbox` either, maintaining **atomicity**.
