#!/usr/bin/env bash
# One-click lite demo. Exit code matches the worst status.

set -u
export LC_ALL=C

ROOT=$(cd "$(dirname "$0")" && pwd) || exit 1
out_dir=""

while [ $# -gt 0 ]; do
  case "$1" in
    --out)
      if [ $# -lt 2 ] || [ -z "$2" ]; then
        printf 'missing path after --out\n' >&2
        exit 2
      fi
      out_dir=$2
      shift 2
      ;;
    -h|--help)
      printf 'Usage: demo.sh [--out DIR]\n'
      exit 0
      ;;
    *)
      printf 'unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

if docker info >/dev/null 2>&1; then
  DOCKER=(docker)
elif command -v sudo >/dev/null 2>&1 && sudo -n docker info >/dev/null 2>&1; then
  DOCKER=(sudo -n docker)
else
  printf 'docker is not available\n' >&2
  exit 1
fi

keep=0
cname="lsc-pack-lite-$$"
if [ -n "$out_dir" ]; then
  mkdir -p "$out_dir" || exit 1
  keep=1
else
  out_dir=$(mktemp -d) || exit 1
fi

run_log=""
run_err=""

# Invoked by the EXIT trap below.
# shellcheck disable=SC2329
cleanup() {
  "${DOCKER[@]}" rm -f "$cname" >/dev/null 2>&1 || true
  if [ "$keep" -eq 0 ] && [ -n "$out_dir" ]; then
    rm -rf "$out_dir"
  fi
  if [ -n "$run_log" ]; then
    rm -f "$run_log"
  fi
  if [ -n "$run_err" ]; then
    rm -f "$run_err"
  fi
}
trap cleanup EXIT

run_log=$(mktemp)
run_err=$(mktemp)

run_container() {
  local net=$1
  local rc=0
  "${DOCKER[@]}" run --rm --name "$cname" --hostname demo-host --network "$net" \
    -v "$ROOT:/opt/linux-server-check:ro" \
    -v "$out_dir:/out" \
    debian:stable-slim \
    bash /opt/linux-server-check/demo/inside.sh >"$run_log" 2>"$run_err" || rc=$?
  cat "$run_log"
  if [ -s "$run_err" ]; then
    cat "$run_err" >&2
  fi
  return "$rc"
}

rc=0
run_container bridge || rc=$?
if ! grep -q '^LSC_EXIT=' "$run_log"; then
  rc=0
  run_container host || rc=$?
fi
exit "$rc"
