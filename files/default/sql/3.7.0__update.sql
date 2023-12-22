-- FSTORE-1119
DELIMITER //

DROP PROCEDURE IF EXISTS add_group_column_to_offset_tables//

CREATE PROCEDURE add_group_column_to_offset_tables()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE db_name VARCHAR(255);

    DECLARE db_cursor CURSOR FOR
        -- get all target databases where consumer_group column does not exist in kafka_offsets table
        SELECT all_db.TABLE_SCHEMA
        FROM INFORMATION_SCHEMA.TABLES all_db
        LEFT JOIN (
            SELECT TABLE_SCHEMA, TABLE_NAME
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_NAME = 'kafka_offsets' AND COLUMN_NAME = 'consumer_group'
        ) target_db ON all_db.TABLE_SCHEMA = target_db.TABLE_SCHEMA AND all_db.TABLE_NAME = target_db.TABLE_NAME
        WHERE all_db.TABLE_NAME = 'kafka_offsets' AND target_db.TABLE_SCHEMA IS NULL;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN db_cursor;

    read_loop: LOOP
        FETCH db_cursor INTO db_name;
        IF done THEN
            LEAVE read_loop;
        END IF;
        SET @alter_query := CONCAT(
                'ALTER TABLE `', db_name, '`.`kafka_offsets` ADD COLUMN `consumer_group` VARCHAR(255) CHARACTER SET latin1 COLLATE latin1_general_cs NOT NULL DEFAULT ''RONDB'''
        );
        PREPARE stmt FROM @alter_query;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END LOOP;

    CLOSE db_cursor;
END //

DELIMITER ;

CALL add_group_column_to_offset_tables();