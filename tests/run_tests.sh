#!/usr/bin/env bash
# Lite preview checks. Prints PASS or FAIL and writes tests/RESULTS.md.

set -u
export LC_ALL=C
export PYTHONDONTWRITEBYTECODE=1

ROOT=$(cd "$(dirname "$0")/.." && pwd) || exit 1
cd "$ROOT" || exit 1

FAILS=0
LOG=$(mktemp)
DETAIL=$(mktemp)
TMP=$(mktemp -d)
HOST=$(hostname 2>/dev/null || true)
IPS=$(hostname -I 2>/dev/null || true)
DOCKER=()
SHELLCHECK_VERSION="not-run"
CLEANED=0

pass() { printf 'PASS: %s\n' "$1" | tee -a "$LOG"; }
fail() { printf 'FAIL: %s\n' "$1" | tee -a "$LOG"; FAILS=$((FAILS + 1)); }
note() { printf '%s\n' "$1" >>"$DETAIL"; }

# Called from write_results.
# shellcheck disable=SC2329
anonymize_file() {
  local src=$1 dest=$2
  python3 - "$src" "$dest" <<'PY'
import re, socket, sys
from pathlib import Path
src, dest = sys.argv[1], sys.argv[2]
text = Path(src).read_text(encoding="utf-8", errors="replace")
hosts = set()
try:
    hosts.add(socket.gethostname())
except OSError:
    pass
try:
    hosts.add(Path("/etc/hostname").read_text(encoding="utf-8", errors="replace").strip())
except OSError:
    pass
for host in sorted((h for h in hosts if h and h != "demo-host"), key=len, reverse=True):
    text = text.replace(host, "demo-host")
def repl(match):
    ip = match.group(0)
    if ip.startswith("127.") or ip.startswith("192.0.2."):
        return ip
    try:
        nums = [int(part) for part in ip.split(".")]
    except ValueError:
        return ip
    if len(nums) != 4 or any(n > 255 for n in nums):
        return ip
    return "192.0.2.%d" % ((nums[3] % 254) + 1)
text = re.sub(r"\b(?:\d{1,3}\.){3}\d{1,3}\b", repl, text)
Path(dest).write_text(text, encoding="utf-8")
PY
}

# Called from the EXIT trap.
# shellcheck disable=SC2329
write_results() {
  local versions safe_log safe_detail
  versions=$(mktemp)
  safe_log=$(mktemp)
  safe_detail=$(mktemp)
  {
    printf 'date: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'bash: %s\n' "$(bash --version | head -n 1)"
    printf 'python: %s\n' "$(python3 --version 2>&1)"
    printf 'docker: %s\n' "$(docker --version 2>/dev/null || printf 'missing')"
    printf 'shellcheck: %s\n' "$SHELLCHECK_VERSION"
  } >"$versions"
  anonymize_file "$LOG" "$safe_log" || cp "$LOG" "$safe_log"
  anonymize_file "$DETAIL" "$safe_detail" || cp "$DETAIL" "$safe_detail"
  anonymize_file "$versions" "$versions.safe" || cp "$versions" "$versions.safe"
  {
    printf '# Lite test results\n\n'
    printf 'Date: %s\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '## Tool versions\n\n'
    printf '```\n'
    cat "$versions.safe"
    printf '```\n\n'
    printf '## Checks\n\n'
    printf '```\n'
    cat "$safe_log"
    printf '```\n\n'
    printf '## Command output\n\n'
    printf '```\n'
    cat "$safe_detail"
    printf '```\n'
  } >"$ROOT/tests/RESULTS.md"
  rm -f "$versions" "$versions.safe" "$safe_log" "$safe_detail"
}

# Called from the EXIT trap.
# shellcheck disable=SC2329
leak_hits() {
  local hits=$1
  : >"$hits"
  if [ -n "$HOST" ] && [ "$HOST" != "demo-host" ]; then
    grep -R -a -n -F --exclude-dir=.git -- "$HOST" "$ROOT" >>"$hits" 2>/dev/null || true
  fi
  local ip
  # shellcheck disable=SC2086
  for ip in $IPS; do
    case "$ip" in
      127.*|192.0.2.*) continue ;;
    esac
    grep -R -a -n -F --exclude-dir=.git -- "$ip" "$ROOT" >>"$hits" 2>/dev/null || true
  done
}

# Invoked by the EXIT trap below.
# shellcheck disable=SC2329
cleanup() {
  if [ "$CLEANED" -eq 1 ]; then
    return 0
  fi
  CLEANED=1
  if [ "${#DOCKER[@]}" -gt 0 ]; then
    local ids vols
    ids=$("${DOCKER[@]}" ps -aq --filter name=lsc-pack- 2>/dev/null || true)
    if [ -n "$ids" ]; then
      # shellcheck disable=SC2086
      "${DOCKER[@]}" rm -f $ids >/dev/null 2>&1 || true
    fi
    vols=$("${DOCKER[@]}" volume ls -q --filter name=lsc-pack- 2>/dev/null || true)
    if [ -n "$vols" ]; then
      # shellcheck disable=SC2086
      "${DOCKER[@]}" volume rm $vols >/dev/null 2>&1 || true
    fi
  fi
  write_results || true
  local hits
  hits=$(mktemp)
  leak_hits "$hits"
  if [ -s "$hits" ]; then
    fail "anonymize leaked hostname or IP"
    note "leak lines:"
    cat "$hits" >>"$DETAIL"
    write_results || true
    rm -f "$hits"
    rm -rf "$TMP"
    exit 1
  fi
  rm -f "$hits"
  rm -rf "$TMP" "$LOG" "$DETAIL"
  if [ "$FAILS" -ne 0 ]; then
    exit 1
  fi
}
trap cleanup EXIT

if docker info >/dev/null 2>&1; then
  DOCKER=(docker)
elif command -v sudo >/dev/null 2>&1 && sudo -n docker info >/dev/null 2>&1; then
  DOCKER=(sudo -n docker)
else
  DOCKER=()
fi

expect_record() {
  local name=$1 expect=$2
  shift 2
  local out rc got want
  rc=0
  out=$("$@" 2>>"$DETAIL") || rc=$?
  note "----- $name exit=$rc -----"
  note "$out"
  got=$(printf '%s\n' "$out" | awk -F= '$1=="STATUS" { print $2; exit }')
  case "$expect" in
    OK) want=0 ;;
    WARN) want=1 ;;
    CRIT) want=2 ;;
    *) want=99 ;;
  esac
  if [ "$got" = "$expect" ] && [ "$rc" -eq "$want" ]; then
    pass "$name"
  else
    fail "$name (status=$got exit=$rc expected $expect/$want)"
  fi
}

missing=0
for f in README.md LICENSE run_all.sh demo.sh checks/disk.sh checks/memory.sh lib/common.sh config.example.conf; do
  if [ ! -f "$f" ]; then
    note "missing $f"
    missing=1
  fi
done
if [ "$missing" -eq 0 ]; then
  pass "lite files exist"
else
  fail "lite files exist"
fi

if grep -q 'Full version / 完整版' README.md \
  && grep -q 'https://caoyadong.gumroad.com/l/nqephae' README.md \
  && grep -q 'https://caoyadong.gumroad.com/l/yvmcqj' README.md \
  && grep -q 'checks/services.sh' README.md \
  && grep -q 'checks/cert.sh' README.md \
  && grep -q 'checks/backup.sh' README.md \
  && grep -q 'checks/load.sh' README.md \
  && grep -q 'health.md' README.md \
  && grep -q 'health.html' README.md \
  && grep -q 'marketing/' README.md \
  && grep -q 'CHANGELOG.md' README.md \
  && grep -q 'Deliverables / 交付物清单' README.md \
  && grep -q 'Estimated setup time / 预计部署时间' README.md \
  && grep -q '中文说明' README.md; then
  pass "lite README points at the full pack"
else
  fail "lite README points at the full pack"
fi

if grep -q 'MIT License' LICENSE && grep -q 'Permission is hereby granted' LICENSE; then
  pass "lite license is MIT"
else
  fail "lite license is MIT"
fi

extra=0
for f in checks/services.sh checks/cert.sh checks/backup.sh checks/load.sh CHANGELOG.md lib/report.sh marketing/listing_en.md; do
  if [ -e "$f" ]; then
    note "full-only file present: $f"
    extra=1
  fi
done
if [ "$extra" -eq 0 ]; then
  pass "full-only files are absent"
else
  fail "full-only files are absent"
fi

syntax_bad=0
while IFS= read -r script; do
  if ! bash -n "$script" 2>>"$DETAIL"; then
    note "bash -n failed: $script"
    syntax_bad=1
  fi
done < <(find "$ROOT" -name '*.sh' -type f | sort)
if [ "$syntax_bad" -eq 0 ]; then
  pass "bash -n lite scripts"
else
  fail "bash -n lite scripts"
fi

if [ "${#DOCKER[@]}" -gt 0 ]; then
  mapfile -t scripts < <(find "$ROOT" -name '*.sh' -type f | sort)
  sc_args=()
  for script in "${scripts[@]}"; do
    sc_args+=("/mnt/${script#"$ROOT"/}")
  done
  if "${DOCKER[@]}" run --rm -v "$ROOT:/mnt:ro" koalaman/shellcheck:stable -x "${sc_args[@]}" >"$TMP/shellcheck.txt" 2>&1; then
    pass "shellcheck lite scripts"
  else
    fail "shellcheck lite scripts"
    cat "$TMP/shellcheck.txt" >>"$DETAIL"
  fi
  SHELLCHECK_VERSION=$("${DOCKER[@]}" run --rm koalaman/shellcheck:stable --version 2>/dev/null | tr '\n' ' ' || true)
else
  fail "docker available for shellcheck"
fi

cat >"$TMP/disk-crit.conf" <<'EOF'
DISK_WARN_PCT=10
DISK_CRIT_PCT=20
INODE_WARN_PCT=100
INODE_CRIT_PCT=100
DISK_PATHS=/
EOF
cat >"$TMP/disk-ok.conf" <<'EOF'
DISK_WARN_PCT=100
DISK_CRIT_PCT=100
INODE_WARN_PCT=100
INODE_CRIT_PCT=100
DISK_PATHS=/
EOF
cat >"$TMP/mem-crit.conf" <<'EOF'
MEM_WARN_PCT=1
MEM_CRIT_PCT=2
SWAP_WARN_PCT=100
SWAP_CRIT_PCT=100
EOF
expect_record "disk critical threshold" CRIT bash checks/disk.sh --config "$TMP/disk-crit.conf"
expect_record "disk clear threshold" OK bash checks/disk.sh --config "$TMP/disk-ok.conf"
expect_record "memory critical threshold" CRIT bash checks/memory.sh --config "$TMP/mem-crit.conf"

report="$TMP/report"
all_rc=0
bash run_all.sh --config "$TMP/disk-ok.conf" --out "$report" >"$TMP/all.stdout" 2>>"$DETAIL" || all_rc=$?
note "----- lite run_all exit=$all_rc -----"
cat "$TMP/all.stdout" >>"$DETAIL"
if [ -f "$report/health.txt" ] && [ ! -f "$report/health.md" ] && [ ! -f "$report/health.html" ]; then
  pass "lite report is text only"
else
  fail "lite report is text only"
fi
overall=$(sed -n 's/^Overall: //p' "$report/health.txt" | head -n 1)
count=$(grep -c '^Status: ' "$report/health.txt" || true)
case "$overall" in
  OK) want=0 ;;
  WARN) want=1 ;;
  CRIT) want=2 ;;
  *) want=99 ;;
esac
if [ "$count" -eq 2 ] && [ "$all_rc" -eq "$want" ]; then
  pass "lite exit matches overall ($overall)"
else
  fail "lite exit matches overall (overall=$overall count=$count exit=$all_rc)"
fi
note "----- lite health.txt -----"
cat "$report/health.txt" >>"$DETAIL"

demo_out="$TMP/demo"
demo_rc=0
bash demo.sh --out "$demo_out" >"$TMP/demo.stdout" 2>"$TMP/demo.stderr" || demo_rc=$?
note "----- lite demo exit=$demo_rc -----"
cat "$TMP/demo.stdout" >>"$DETAIL"
note "----- lite demo stderr -----"
cat "$TMP/demo.stderr" >>"$DETAIL"
if [ -f "$demo_out/health.txt" ] && [ ! -f "$demo_out/health.md" ]; then
  pass "lite container demo writes a text report"
else
  fail "lite container demo writes a text report"
fi
demo_overall=$(sed -n 's/^Overall: //p' "$demo_out/health.txt" 2>/dev/null | head -n 1 || true)
case "$demo_overall" in
  OK) demo_want=0 ;;
  WARN) demo_want=1 ;;
  CRIT) demo_want=2 ;;
  *) demo_want=99 ;;
esac
if [ "$demo_rc" -eq "$demo_want" ]; then
  pass "lite demo exit matches overall ($demo_overall)"
else
  fail "lite demo exit matches overall (overall=$demo_overall exit=$demo_rc)"
fi

png_ok=1
for png in screenshots/01-text-report.png screenshots/02-check-output.png; do
  if ! python3 - "$png" >>"$DETAIL" 2>&1 <<'PY'
import sys
from PIL import Image
path = sys.argv[1]
im = Image.open(path)
print(path, im.size, im.format)
if im.format != "PNG" or im.size[0] < 200 or im.size[1] < 200:
    raise SystemExit(1)
PY
  then
    png_ok=0
  fi
done
if [ "$png_ok" -eq 1 ]; then
  pass "lite screenshots are pngs"
else
  fail "lite screenshots are pngs"
fi

note "FAILS=$FAILS"
printf 'Lite results: %s failure(s). See tests/RESULTS.md\n' "$FAILS"
exit "$FAILS"
