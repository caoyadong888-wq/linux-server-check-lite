#!/usr/bin/env bash
# Lite preview: disk and memory only, text report only.
# Exit 0 OK, 1 WARN, 2 CRIT.
# Record fields are filled by lsc_read_record in lib/common.sh.
# shellcheck disable=SC2154

set -u

ROOT=$(cd "$(dirname "$0")" && pwd) || exit 2
export LC_ALL=C
# shellcheck source=lib/common.sh
. "$ROOT/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: run_all.sh [--config FILE] [--out DIR]

Runs disk and memory checks and writes DIR/health.txt.
The default directory is ./report.
EOF
}

write_text() {
  local dest=$1
  local overall=$2
  local generated=$3
  local host=$4
  shift 4
  local file
  {
    printf 'Linux Server Health Check (lite)\n'
    printf 'Pack: lite\n'
    printf 'Generated (UTC): %s\n' "$generated"
    printf 'Host: %s\n' "$host"
    printf 'Overall: %s\n' "$overall"
    printf '\n'
    for file in "$@"; do
      lsc_read_record "$file"
      printf '%s\n' '------------------------------------------------------------'
      printf 'Check: %s\n' "$LSC_R_CHECK"
      printf 'Status: %s\n' "$LSC_R_STATUS"
      printf 'Summary: %s\n' "$LSC_R_SUMMARY"
      printf 'Evidence:\n'
      if [ -n "$LSC_R_EVIDENCE" ]; then
        printf '%s\n' "$LSC_R_EVIDENCE" | sed 's/^/    /'
      else
        printf '    (none)\n'
      fi
      printf 'Recommendation:\n'
      if [ -n "$LSC_R_RECOMMENDATION" ]; then
        printf '%s\n' "$LSC_R_RECOMMENDATION" | sed 's/^/    /'
      else
        printf '    (none)\n'
      fi
      printf '\n'
    done
  } >"$dest"
}

main() {
  local config="" out_dir="report"
  while [ $# -gt 0 ]; do
    case "$1" in
      --config)
        if [ $# -lt 2 ]; then
          printf 'missing path after --config\n' >&2
          exit 2
        fi
        config=$2
        shift 2
        ;;
      --out)
        if [ $# -lt 2 ]; then
          printf 'missing path after --out\n' >&2
          exit 2
        fi
        out_dir=$2
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        printf 'unknown argument: %s\n' "$1" >&2
        exit 2
        ;;
    esac
  done

  if [ -n "$config" ] && [ ! -f "$config" ]; then
    printf 'config file not found: %s\n' "$config" >&2
    exit 2
  fi
  mkdir -p "$out_dir" || exit 2

  local work
  work=$(mktemp -d)
  # shellcheck disable=SC2064
  trap 'rm -rf "'"$work"'"' EXIT

  local checks=(disk memory)
  local c script rc overall
  overall=OK
  for c in "${checks[@]}"; do
    script=$ROOT/checks/$c.sh
    rc=0
    if [ -n "$config" ]; then
      bash "$script" --config "$config" >"$work/$c.out" 2>"$work/$c.err" || rc=$?
    else
      bash "$script" >"$work/$c.out" 2>"$work/$c.err" || rc=$?
    fi
    if ! grep -q '^STATUS=\(OK\|WARN\|CRIT\)$' "$work/$c.out"; then
      {
        printf 'STATUS=CRIT\n'
        printf 'CHECK=%s\n' "$c"
        printf 'SUMMARY=Check did not return a status\n'
        printf 'EVIDENCE_BEGIN\n'
        printf 'exit=%s\n' "$rc"
        cat "$work/$c.out" 2>/dev/null || true
        cat "$work/$c.err" 2>/dev/null || true
        printf 'EVIDENCE_END\n'
        printf 'RECOMMENDATION_BEGIN\n'
        printf 'Run checks/%s.sh and read the evidence.\n' "$c"
        printf 'RECOMMENDATION_END\n'
      } >"$work/$c.fixed"
      mv "$work/$c.fixed" "$work/$c.out"
    fi
    lsc_read_record "$work/$c.out"
    overall=$(lsc_worse "$overall" "$LSC_R_STATUS")
  done

  local generated host files
  generated=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  host=$(hostname 2>/dev/null || printf 'unknown')
  files=("$work/disk.out" "$work/memory.out")
  write_text "$out_dir/health.txt" "$overall" "$generated" "$host" "${files[@]}" || exit 2
  printf 'Overall: %s\n' "$overall"
  printf 'Wrote %s/health.txt\n' "$out_dir"
  case "$overall" in
    OK) exit 0 ;;
    WARN) exit 1 ;;
    *) exit 2 ;;
  esac
}

main "$@"
