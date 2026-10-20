#!/usr/bin/env bash
# Read-only memory, swap, and OOM check. Does not change sysctl or processes.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd) || exit 2
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

usage() {
  cat <<'EOF'
Usage: memory.sh [--config FILE]

Read /proc/meminfo and, when readable, scan dmesg for OOM killer lines.
Uses sudo -n dmesg only when dmesg is denied and passwordless sudo works.
EOF
}

mem_field() {
  local key=$1
  awk -v k="$key" '$1 == k { print $2; exit }' /proc/meminfo
}

main() {
  local config=""
  MEM_WARN_PCT=80
  MEM_CRIT_PCT=95
  SWAP_WARN_PCT=50
  SWAP_CRIT_PCT=80

  while [ $# -gt 0 ]; do
    case "$1" in
      --config)
        if [ $# -lt 2 ]; then
          lsc_emit CRIT memory "Missing config path" "--config needs a file" "Pass --config FILE."
        fi
        config=$2
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        lsc_emit CRIT memory "Unknown argument" "$1" "Use --config FILE or --help."
        ;;
    esac
  done

  if [ -n "$config" ]; then
    lsc_load_config "$config" memory
  fi
  lsc_require_uint MEM_WARN_PCT "$MEM_WARN_PCT" memory 100
  lsc_require_uint MEM_CRIT_PCT "$MEM_CRIT_PCT" memory 100
  lsc_require_uint SWAP_WARN_PCT "$SWAP_WARN_PCT" memory 100
  lsc_require_uint SWAP_CRIT_PCT "$SWAP_CRIT_PCT" memory 100
  lsc_require_ordered memory MEM_WARN_PCT "$MEM_WARN_PCT" MEM_CRIT_PCT "$MEM_CRIT_PCT"
  lsc_require_ordered memory SWAP_WARN_PCT "$SWAP_WARN_PCT" SWAP_CRIT_PCT "$SWAP_CRIT_PCT"

  if [ ! -r /proc/meminfo ]; then
    lsc_emit CRIT memory "Cannot read /proc/meminfo" "path=/proc/meminfo" "Run this check on Linux with /proc mounted."
  fi

  local mem_total mem_avail mem_free buffers cached
  local swap_total swap_free used_pct swap_pct swap_show
  local overall mem_level swap_level
  local evidence="" dmesg_state oom_count oom_line raw_line
  mem_total=$(mem_field "MemTotal:")
  mem_avail=$(mem_field "MemAvailable:")
  case "$mem_total" in
    ''|*[!0-9]*)
      lsc_emit CRIT memory "MemTotal is missing" "MemTotal=$mem_total" "Run this check on Linux with /proc/meminfo."
      ;;
  esac
  if [ -z "$mem_avail" ]; then
    mem_free=$(mem_field "MemFree:")
    buffers=$(mem_field "Buffers:")
    cached=$(mem_field "Cached:")
    mem_free=${mem_free:-0}
    buffers=${buffers:-0}
    cached=${cached:-0}
    mem_avail=$((mem_free + buffers + cached))
  fi
  if [ "$mem_avail" -gt "$mem_total" ]; then
    used_pct=0
  else
    used_pct=$(( (mem_total - mem_avail) * 100 / mem_total ))
  fi
  mem_level=$(lsc_pct_level "$used_pct" "$MEM_WARN_PCT" "$MEM_CRIT_PCT")
  overall=$mem_level

  swap_total=$(mem_field "SwapTotal:")
  swap_free=$(mem_field "SwapFree:")
  swap_total=${swap_total:-0}
  swap_free=${swap_free:-0}
  swap_level=OK
  if [ "$swap_total" -eq 0 ]; then
    swap_show="n/a"
    swap_pct="n/a"
  else
    swap_pct=$(( (swap_total - swap_free) * 100 / swap_total ))
    swap_show="${swap_pct}%"
    swap_level=$(lsc_pct_level "$swap_pct" "$SWAP_WARN_PCT" "$SWAP_CRIT_PCT")
    overall=$(lsc_worse "$overall" "$swap_level")
  fi

  dmesg_state=unreadable
  oom_count=0
  raw_line=""
  if command -v dmesg >/dev/null 2>&1 && dmesg >/dev/null 2>&1; then
    dmesg_state=readable
    raw_line=$(dmesg 2>/dev/null | grep -Ei 'out of memory|oom-kill|oom_kill|Killed process' | tail -n 10 || true)
  elif command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1 && sudo -n dmesg >/dev/null 2>&1; then
    dmesg_state=readable-via-sudo
    raw_line=$(sudo -n dmesg 2>/dev/null | grep -Ei 'out of memory|oom-kill|oom_kill|Killed process' | tail -n 10 || true)
  fi

  evidence=$(lsc_add_line "$evidence" "thresholds mem_warn=${MEM_WARN_PCT} mem_crit=${MEM_CRIT_PCT} swap_warn=${SWAP_WARN_PCT} swap_crit=${SWAP_CRIT_PCT}")
  evidence=$(lsc_add_line "$evidence" "mem_total_kb=$mem_total mem_available_kb=$mem_avail mem_used_pct=$used_pct mem_level=$mem_level")
  evidence=$(lsc_add_line "$evidence" "swap_total_kb=$swap_total swap_free_kb=$swap_free swap_used_pct=$swap_show swap_level=$swap_level")
  evidence=$(lsc_add_line "$evidence" "dmesg=$dmesg_state")
  if [ -n "$raw_line" ]; then
    while IFS= read -r oom_line; do
      [ -n "$oom_line" ] || continue
      oom_line=$(printf '%s' "$oom_line" | cut -c 1-200)
      oom_count=$((oom_count + 1))
      evidence=$(lsc_add_line "$evidence" "oom=$oom_line")
    done <<< "$raw_line"
    overall=$(lsc_worse "$overall" WARN)
  else
    evidence=$(lsc_add_line "$evidence" "oom_lines=0")
  fi

  local summary recommendation
  case "$overall" in
    OK)
      summary="Memory is within thresholds and dmesg shows no OOM lines."
      recommendation="No action required."
      if [ "$dmesg_state" = unreadable ]; then
        summary="Memory is within thresholds. dmesg could not be read."
        recommendation="No memory action required. To include OOM history, allow the user to read dmesg or grant passwordless sudo for dmesg only."
      fi
      ;;
    WARN)
      summary="Memory, swap, or kernel OOM history crossed the warning line."
      recommendation="Plan capacity before memory or swap reaches the critical threshold."
      ;;
    *)
      summary="Memory or swap is at or above the critical threshold."
      recommendation="Add memory, reduce the workload, or stop a leaking process. A host this low on memory can start killing processes."
      ;;
  esac
  if [ "$oom_count" -gt 0 ]; then
    recommendation="Kernel OOM lines are in the evidence ($oom_count). Find what was killed and add memory or lower the workload. $recommendation"
  fi
  if [ "$swap_total" -eq 0 ]; then
    recommendation="$recommendation Swap is not configured; that is reported and is not by itself a warning."
  fi
  lsc_emit "$overall" memory "$summary" "$evidence" "$recommendation"
}

main "$@"
