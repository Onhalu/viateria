#!/usr/bin/env bash
# Upload a local directory to WEDOS FTPS with PASV-IP skip and per-file retries.
#
# WEDOS constraints (do not "simplify" this back to lftp mirror):
# - FTP home is the hosting www root. Upload only to
#   domains/viateria.limitlessdreams.cz (relative to that home).
# - Empty or "/" FTP_PATH must default to that directory, never "/".
# - Never create or upload under subdom/ — that 500s the vhost when
#   domains/viateria.limitlessdreams.cz also exists.
# - PASV replies a private IP; without --ftp-skip-pasv-ip curl/lftp get
#   "425 Security: Bad IP connecting".
set -euo pipefail

readonly DEFAULT_REMOTE_DIR='domains/viateria.limitlessdreams.cz'
readonly MAX_ATTEMPTS=5

usage() {
  cat <<'EOF'
Usage:
  wedos_ftp_upload.sh <local-dir>
  wedos_ftp_upload.sh --print-remote-path
  wedos_ftp_upload.sh --self-check

Env:
  FTP_HOST   WEDOS FTP hostname (required for upload)
  FTP_USER   FTP username (required for upload)
  FTP_PASS   FTP password (required for upload)
  FTP_PATH   Remote directory relative to FTP home. Empty or "/" defaults
             to domains/viateria.limitlessdreams.cz
EOF
}

trim() {
  local value="${1-}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

strip_slashes() {
  local value="${1-}"
  while [[ "$value" == /* ]]; do
    value="${value#/}"
  done
  while [[ "$value" == */ ]]; do
    value="${value%/}"
  done
  printf '%s' "$value"
}

# Returns 0 if the path is forbidden (subdom or absolute root).
is_forbidden_remote_path() {
  local value
  value="$(strip_slashes "$(trim "${1-}")")"
  local lowered
  lowered="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
  if [[ -z "$lowered" ]]; then
    return 0
  fi
  if [[ "$lowered" == 'subdom' || "$lowered" == subdom/* || "$lowered" == */subdom || "$lowered" == */subdom/* ]]; then
    return 0
  fi
  return 1
}

resolve_remote_path() {
  local raw
  raw="$(trim "${1-}")"
  if [[ -z "$raw" || "$raw" == '/' ]]; then
    printf '%s' "$DEFAULT_REMOTE_DIR"
    return 0
  fi
  local normalized
  normalized="$(strip_slashes "$raw")"
  if [[ -z "$normalized" ]]; then
    printf '%s' "$DEFAULT_REMOTE_DIR"
    return 0
  fi
  if is_forbidden_remote_path "$normalized"; then
    echo "Refusing WEDOS path '$raw': never upload to / or subdom/." >&2
    echo "Use ${DEFAULT_REMOTE_DIR} (relative to the FTP home)." >&2
    return 1
  fi
  printf '%s' "$normalized"
}

urlencode_path() {
  python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe="/"))' "$1"
}

upload_one() {
  local local_file="$1"
  local remote_url="$2"
  local attempt=1
  local sleep_s=2
  while (( attempt <= MAX_ATTEMPTS )); do
    if curl \
      --ssl-reqd \
      --ftp-pasv \
      --ftp-skip-pasv-ip \
      --ftp-create-dirs \
      --connect-timeout 30 \
      --max-time 180 \
      --silent \
      --show-error \
      --fail \
      --user "${FTP_USER}:${FTP_PASS}" \
      --upload-file "$local_file" \
      "$remote_url"; then
      return 0
    fi
    echo "Upload failed (attempt ${attempt}/${MAX_ATTEMPTS}): ${local_file}" >&2
    if (( attempt == MAX_ATTEMPTS )); then
      echo "Giving up on ${local_file} -> ${remote_url}" >&2
      return 1
    fi
    sleep "$sleep_s"
    sleep_s=$((sleep_s * 2))
    attempt=$((attempt + 1))
  done
}

self_check() {
  local got
  got="$(resolve_remote_path '')"
  [[ "$got" == "$DEFAULT_REMOTE_DIR" ]] || {
    echo "empty path should default, got: $got" >&2
    return 1
  }
  got="$(resolve_remote_path '/')"
  [[ "$got" == "$DEFAULT_REMOTE_DIR" ]] || {
    echo "'/' should default, got: $got" >&2
    return 1
  }
  got="$(resolve_remote_path '///')"
  [[ "$got" == "$DEFAULT_REMOTE_DIR" ]] || {
    echo "'///' should default, got: $got" >&2
    return 1
  }
  got="$(resolve_remote_path "  ${DEFAULT_REMOTE_DIR}/  ")"
  [[ "$got" == "$DEFAULT_REMOTE_DIR" ]] || {
    echo "trimmed default path mismatch: $got" >&2
    return 1
  }
  if resolve_remote_path 'subdom/viateria' >/dev/null 2>&1; then
    echo "subdom/viateria must be rejected" >&2
    return 1
  fi
  if resolve_remote_path '/subdom/viateria/' >/dev/null 2>&1; then
    echo "/subdom/viateria/ must be rejected" >&2
    return 1
  fi
  echo "WEDOS path rules ok (default: ${DEFAULT_REMOTE_DIR})"
}

upload_tree() {
  local local_dir="$1"
  if [[ ! -d "$local_dir" ]]; then
    echo "Local directory not found: $local_dir" >&2
    return 1
  fi
  : "${FTP_HOST:?FTP_HOST is required}"
  : "${FTP_USER:?FTP_USER is required}"
  : "${FTP_PASS:?FTP_PASS is required}"

  local remote_dir
  remote_dir="$(resolve_remote_path "${FTP_PATH-}")"
  echo "Uploading ${local_dir} -> ${FTP_HOST}/${remote_dir} (FTPS PASV, skip-pasv-ip)"

  local local_dir_abs
  local_dir_abs="$(cd "$local_dir" && pwd)"
  local file rel encoded remote_url count=0
  while IFS= read -r -d '' file; do
    rel="${file#"${local_dir_abs}/"}"
    encoded="$(urlencode_path "${remote_dir}/${rel}")"
    remote_url="ftp://${FTP_HOST}/${encoded}"
    echo "  ${rel}"
    if [[ "${DRY_RUN:-}" == '1' ]]; then
      echo "    -> ${remote_url}"
    else
      upload_one "$file" "$remote_url"
    fi
    count=$((count + 1))
  done < <(find "$local_dir_abs" -type f -print0)

  if (( count == 0 )); then
    echo "No files found under ${local_dir_abs}" >&2
    return 1
  fi
  echo "Uploaded ${count} files to ${remote_dir}"
}

main() {
  case "${1-}" in
    -h | --help)
      usage
      ;;
    --print-remote-path)
      resolve_remote_path "${FTP_PATH-}"
      echo
      ;;
    --self-check)
      self_check
      ;;
    '')
      usage >&2
      return 1
      ;;
    *)
      upload_tree "$1"
      ;;
  esac
}

main "$@"
