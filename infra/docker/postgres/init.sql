CREATE DATABASE quiz_service;
CREATE DATABASE profile_service;
CREATE DATABASE auth_service;

-- CREATE EXTENSION IF NOT EXISTS vector;
-- CREATE EXTENSION IF NOT EXISTS hstore;
-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- -- DROP TABLE vector_store;
-- CREATE TABLE IF NOT EXISTS vector_store
-- (
--     id        uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
--     content   text,
--     metadata  json,
--     embedding vector(1536) -- Match Vertex AI dims
-- );
-- CREATE INDEX ON vector_store USING HNSW (embedding vector_cosine_ops);
