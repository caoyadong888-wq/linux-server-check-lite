#!/usr/bin/env bash
# Runs inside debian:stable-slim for the lite preview.

set -u
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive
umask 022

apt_ok=0
try=0
while [ "$try" -lt 2 ]; do
  try=$((try + 1))
  if apt-get update -qq >/dev/null 2>&1 && apt-get install -y -qq procps >/dev/null 2>&1; then
    apt_ok=1
    break
  fi
  sleep 2
done
if [ "$apt_ok" -ne 1 ]; then
  printf 'apt-get failed\n' >&2
  exit 1
fi

cd /opt/linux-server-check || exit 1
mkdir -p /out
rc=0
bash ./run_all.sh --config demo/demo.conf --out /out || rc=$?
chmod -R a+rX /out || true
printf 'LSC_EXIT=%s\n' "$rc"
if [ -f /out/health.txt ]; then
  printf '===== health.txt =====\n'
  cat /out/health.txt
fi
exit "$rc"
