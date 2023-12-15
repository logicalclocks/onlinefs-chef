-- Check if the table 'kafka_offsets' exists in the current database
IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = DATABASE()
      AND table_name = 'kafka_offsets'
) THEN
    -- Check if the column 'consumer_group' exists
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = 'kafka_offsets'
          AND column_name = 'consumer_group'
    ) THEN
        -- Add the column 'consumer_group' with type VARCHAR
        ALTER TABLE kafka_offsets ADD COLUMN consumer_group VARCHAR(255) CHARACTER SET latin1 COLLATE latin1_general_cs NOT NULL DEFAULT 'RONDB';
    END IF;
END IF;
