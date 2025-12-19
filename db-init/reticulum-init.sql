-- Initialize Reticulum ret_dev database
-- This script is run automatically by PostgreSQL on container startup
-- via the /docker-entrypoint-initdb.d/ directory

-- Create ret_dev database
CREATE DATABASE ret_dev;

-- Connect to ret_dev and set up basic schema
\c ret_dev;

-- Create necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "citext";

-- Create tables required by Reticulum/Ecto
-- These will be created by Ecto migrations when Reticulum starts,
-- but we ensure the schema is ready

-- Create basic schema structure for Ecto schema_migrations tracking
CREATE TABLE IF NOT EXISTS schema_migrations (
  version BIGINT NOT NULL PRIMARY KEY,
  inserted_at TIMESTAMP NOT NULL
);

GRANT ALL PRIVILEGES ON DATABASE ret_dev TO postgres;
GRANT ALL PRIVILEGES ON SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
