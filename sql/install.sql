-- Every table is created automatically on first start. Only run this by hand if
-- your database user cannot create tables.

CREATE TABLE IF NOT EXISTS `dynamicworld_sickness` (
    `identifier` VARCHAR(64) NOT NULL,
    `sickness` VARCHAR(50) DEFAULT NULL,
    `severity` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `stage` VARCHAR(20) DEFAULT NULL,
    `exposure` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `immune_until` INT UNSIGNED NOT NULL DEFAULT 0,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`identifier`)
);

CREATE TABLE IF NOT EXISTS `dynamicworld_climates` (
    `id` VARCHAR(32) NOT NULL,
    `label` VARCHAR(20) NOT NULL,
    `colour` CHAR(7) NOT NULL,
    `day` TINYINT NOT NULL,
    `night` TINYINT NOT NULL,
    `humidity` TINYINT UNSIGNED NOT NULL,
    `duration_min` SMALLINT UNSIGNED NOT NULL,
    `duration_max` SMALLINT UNSIGNED NOT NULL,
    `wind` DECIMAL(2,1) NOT NULL DEFAULT 1.0,
    `seasons` TINYINT(1) NOT NULL DEFAULT 1,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
);

CREATE TABLE IF NOT EXISTS `dynamicworld_climate_weathers` (
    `climate` VARCHAR(32) NOT NULL,
    `weather` VARCHAR(16) NOT NULL,
    `weight` TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (`climate`, `weather`),
    FOREIGN KEY (`climate`) REFERENCES `dynamicworld_climates` (`id`) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS `dynamicworld_regions` (
    `id` VARCHAR(48) NOT NULL,
    `label` VARCHAR(20) NOT NULL,
    `climate` VARCHAR(32) NOT NULL,
    `shape` ENUM('global', 'circle', 'poly') NOT NULL,
    `x` FLOAT NULL,
    `y` FLOAT NULL,
    `radius` FLOAT NULL,
    `priority` TINYINT UNSIGNED NOT NULL DEFAULT 10,
    `floor` FLOAT NULL,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
);

CREATE TABLE IF NOT EXISTS `dynamicworld_region_points` (
    `region` VARCHAR(48) NOT NULL,
    `idx` TINYINT UNSIGNED NOT NULL,
    `x` FLOAT NOT NULL,
    `y` FLOAT NOT NULL,
    PRIMARY KEY (`region`, `idx`),
    FOREIGN KEY (`region`) REFERENCES `dynamicworld_regions` (`id`) ON DELETE CASCADE
);
