#!/usr/bin/env bash
set -euo pipefail
psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  --set=app_password="$APP_PASSWORD" --set=reader_password="$READ_PASSWORD" \
  --set=ON_ERROR_STOP=1 <<'SQL'
CREATE ROLE asteria_app LOGIN PASSWORD :'app_password';
CREATE ROLE asteria_reader LOGIN PASSWORD :'reader_password';
GRANT CONNECT ON DATABASE playground TO asteria_app, asteria_reader;
GRANT USAGE, CREATE ON SCHEMA public TO asteria_app;
GRANT USAGE ON SCHEMA public TO asteria_reader;
ALTER DEFAULT PRIVILEGES FOR ROLE asteria_app IN SCHEMA public
  GRANT SELECT ON TABLES TO asteria_reader;
SQL
