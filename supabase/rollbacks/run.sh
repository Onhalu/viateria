#!/bin/sh
# Run one rollback file with psql -v ON_ERROR_STOP=1 -f.
# A refused guard is a non-zero exit. psql exits 0 after a SQL error
# unless ON_ERROR_STOP is set.
#
#   supabase/rollbacks/run.sh supabase/rollbacks/<file>.rollback.sql
#   ALLOW_ROLLBACK=1 supabase/rollbacks/run.sh supabase/rollbacks/<file>.rollback.sql
set -eu

file=${1:?usage: run.sh path/to/file.rollback.sql}

if [ "${ALLOW_ROLLBACK:-}" = "1" ]; then
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT
  {
    echo "SELECT set_config('viateria.allow_rollback','on',false);"
    cat "$file"
  } > "$tmp"
  exec psql -v ON_ERROR_STOP=1 -f "$tmp"
fi

exec psql -v ON_ERROR_STOP=1 -f "$file"
