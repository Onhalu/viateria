#!/bin/sh
# Plain psql -f: no GUC, no --single-transaction, no ON_ERROR_STOP.
# A guard error must abort the file's transaction and drop nothing.
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
export PGHOST="${PGHOST:-127.0.0.1}"
export PGPORT="${PGPORT:-54322}"
export PGUSER="${PGUSER:-postgres}"
export PGDATABASE="${PGDATABASE:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"

docker_cmd() {
  if docker info >/dev/null 2>&1; then
    docker "$@"
  else
    sudo docker "$@"
  fi
}

run_file() {
  if command -v psql >/dev/null 2>&1; then
    psql -f "$1"
    return
  fi
  docker_cmd exec -i supabase_db_viateria \
    sh -c 'cat > /tmp/vandery-rollback.sql' < "$1"
  docker_cmd exec -e PGPASSWORD="$PGPASSWORD" supabase_db_viateria \
    psql -U "$PGUSER" -d "$PGDATABASE" -f /tmp/vandery-rollback.sql
}

psql_at() {
  if command -v psql >/dev/null 2>&1; then
    psql -Atc "$1"
    return
  fi
  docker_cmd exec -e PGPASSWORD="$PGPASSWORD" supabase_db_viateria \
    psql -U "$PGUSER" -d "$PGDATABASE" -Atc "$1"
}

assert_kept() {
  result=$(psql_at "$2")
  if [ "$result" != "t" ]; then
    echo "expected to keep $1" >&2
    exit 1
  fi
  echo "kept $1"
}

for rollback in "$root"/supabase/rollbacks/*.sql; do
  if ! grep -q "raise exception 'viateria.allow_destructive_rollback" "$rollback"; then
    echo "missing guard: $rollback" >&2
    exit 1
  fi
  echo "guard present $(basename "$rollback")"
done

cmp_fixture() {
  if [ ! -f "$1" ] || [ ! -f "$2" ]; then
    echo "fixture mismatch: missing $1 or $2" >&2
    exit 1
  fi
  if ! cmp -s "$1" "$2"; then
    echo "fixture mismatch: $1 and $2" >&2
    exit 1
  fi
  echo "fixture matches $(basename "$2")"
}

found_fixture=0
for fixture in "$root"/supabase/tests/fixtures/*; do
  [ -f "$fixture" ] || continue
  found_fixture=1
  base=$(basename "$fixture")
  cmp_fixture "$root/supabase/rollbacks/${base}.sql" "$fixture"
done
if [ "$found_fixture" -eq 0 ]; then
  echo "fixture mismatch: no fixtures to compare" >&2
  exit 1
fi

run_file "$root/supabase/rollbacks/20261106113000_vandery_plus_membership.rollback.sql"
run_file "$root/supabase/rollbacks/20261106114000_vandery_plus_diplomas.rollback.sql"
run_file "$root/supabase/rollbacks/20261106120300_vandery_plus_dba_p2.rollback.sql"
run_file "$root/supabase/rollbacks/20261106120200_vandery_plus_dba_p1_p2.rollback.sql"
run_file "$root/supabase/rollbacks/20261106120100_vandery_plus_invoice_idempotency.rollback.sql"
run_file "$root/supabase/rollbacks/20261106120000_record_place_visit_source_guard.rollback.sql"

assert_kept vandery_plus_memberships \
  "select to_regclass('public.vandery_plus_memberships') is not null"
assert_kept vandery_plus_webhook_events \
  "select to_regclass('public.vandery_plus_webhook_events') is not null"
assert_kept private.commit_vandery_plus_event \
  "select to_regprocedure('private.commit_vandery_plus_event(uuid,uuid,text,text,text,jsonb)') is not null"
assert_kept vandery_plus_user_diplomas \
  "select to_regclass('public.vandery_plus_user_diplomas') is not null"
assert_kept vandery_plus_diplomas \
  "select to_regclass('public.vandery_plus_diplomas') is not null"
assert_kept can_record_place_visit \
  "select to_regprocedure('public.can_record_place_visit(text)') is not null"
assert_kept place_visits_insert_own \
  "select exists (
     select 1
     from pg_policies
     where schemaname = 'public'
       and tablename = 'place_visits'
       and policyname = 'place_visits_insert_own'
       and with_check ilike '%can_record_place_visit%'
   )"
