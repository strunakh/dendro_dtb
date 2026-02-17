-- dendro metadáta
CREATE TABLE IF NOT EXISTS dendro_meta (
    dendro_id TEXT PRIMARY KEY,
    belt TEXT,
    plot TEXT,
    species TEXT,
    dbh_cm DOUBLE PRECISION,
    size_class TEXT,
    date_of_installation DATE,
    x DOUBLE PRECISION,
    y DOUBLE PRECISION
);

-- dendro dáta
CREATE TABLE IF NOT EXISTS dendro_data (
    dendro_id TEXT NOT NULL REFERENCES dendro_meta(dendro_id),
    ts TIMESTAMP NOT NULL,
    increment DOUBLE PRECISION,
    temp DOUBLE PRECISION,
    PRIMARY KEY (dendro_id, ts)
);

-- meteo metadáta
CREATE TABLE IF NOT EXISTS meteo_meta (
    meteo_id TEXT PRIMARY KEY,
    belt TEXT,
    plot TEXT,
    size_class TEXT,
    date_of_installation DATE,
    x DOUBLE PRECISION,
    y DOUBLE PRECISION
);

-- meteo raw dáta
CREATE TABLE IF NOT EXISTS meteo_data (
    meteo_id TEXT NOT NULL REFERENCES meteo_meta(meteo_id),
    ts TIMESTAMP NOT NULL,
    temp DOUBLE PRECISION,
    humidity DOUBLE PRECISION,
    dew_point DOUBLE PRECISION,
    PRIMARY KEY (meteo_id, ts)
);