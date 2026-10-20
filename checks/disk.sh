#!/usr/bin/env bash
# Read-only disk usage and inode check. Does not mount, delete, or write.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd) || exit 2
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

usage() {
  cat <<'EOF'
Usage: disk.sh [--config FILE]

Read filesystem usage and inode use. Compare them with DISK_* and INODE_* thresholds.
Print one record and exit 0 (OK), 1 (WARN), or 2 (CRIT).
EOF
}

disk_one() {
  local mount=$1
  local df_rc=0
  local df_out parsed target fstype used_s inode_s source used_n inode_n
  local used_level inode_level level inode_show
  df_out=$(df --output=target,fstype,pcent,ipcent,source -- "$mount" 2>&1) || df_rc=$?
  if [ "$df_rc" -ne 0 ]; then
    evidence=$(lsc_add_line "$evidence" "mount=$mount level=CRIT detail=df_failed")
    overall=$(lsc_worse "$overall" CRIT)
    return 0
  fi
  parsed=$(printf '%s\n' "$df_out" | awk 'NR==2 {
    pc=$3; ip=$4; src=$5
    for (i=6; i<=NF; i++) src=src " " $i
    gsub(/%/, "", pc)
    gsub(/%/, "", ip)
    printf "%s\t%s\t%s\t%s\t%s\n", $1, $2, pc, ip, src
  }')
  if [ -z "$parsed" ]; then
    evidence=$(lsc_add_line "$evidence" "mount=$mount level=CRIT detail=df_unparsed")
    overall=$(lsc_worse "$overall" CRIT)
    return 0
  fi
  IFS=$'\t' read -r target fstype used_s inode_s source <<< "$parsed"
  case "$used_s" in
    ''|*[!0-9]*)
      evidence=$(lsc_add_line "$evidence" "mount=$mount level=CRIT detail=bad_usage_pct value=$used_s")
      overall=$(lsc_worse "$overall" CRIT)
      return 0
      ;;
  esac
  used_n=$((10#$used_s))
  used_level=$(lsc_pct_level "$used_n" "$DISK_WARN_PCT" "$DISK_CRIT_PCT")
  inode_show=n/a
  inode_level=OK
  case "$inode_s" in
    ''|-) ;;
    *[!0-9]*)
      inode_show=$inode_s
      inode_level=CRIT
      ;;
    *)
      inode_n=$((10#$inode_s))
      inode_show="${inode_n}%"
      inode_level=$(lsc_pct_level "$inode_n" "$INODE_WARN_PCT" "$INODE_CRIT_PCT")
      ;;
  esac
  level=$(lsc_worse "$used_level" "$inode_level")
  overall=$(lsc_worse "$overall" "$level")
  evidence=$(lsc_add_line "$evidence" "mount=$target fstype=$fstype used=${used_n}% inodes=$inode_show fs=$source level=$level requested=$mount")
}

main() {
  local config=""
  local evidence="" overall="OK"
  local mount fstype target
  DISK_WARN_PCT=80
  DISK_CRIT_PCT=90
  INODE_WARN_PCT=80
  INODE_CRIT_PCT=90
  DISK_PATHS=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --config)
        if [ $# -lt 2 ]; then
          lsc_emit CRIT disk "Missing config path" "--config needs a file" "Pass --config FILE."
        fi
        config=$2
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        lsc_emit CRIT disk "Unknown argument" "$1" "Use --config FILE or --help."
        ;;
    esac
  done

  if [ -n "$config" ]; then
    lsc_load_config "$config" disk
  fi
  lsc_require_uint DISK_WARN_PCT "$DISK_WARN_PCT" disk 100
  lsc_require_uint DISK_CRIT_PCT "$DISK_CRIT_PCT" disk 100
  lsc_require_uint INODE_WARN_PCT "$INODE_WARN_PCT" disk 100
  lsc_require_uint INODE_CRIT_PCT "$INODE_CRIT_PCT" disk 100
  lsc_require_ordered disk DISK_WARN_PCT "$DISK_WARN_PCT" DISK_CRIT_PCT "$DISK_CRIT_PCT"
  lsc_require_ordered disk INODE_WARN_PCT "$INODE_WARN_PCT" INODE_CRIT_PCT "$INODE_CRIT_PCT"

  evidence=$(lsc_add_line "$evidence" "thresholds used_warn=${DISK_WARN_PCT} used_crit=${DISK_CRIT_PCT} inode_warn=${INODE_WARN_PCT} inode_crit=${INODE_CRIT_PCT}")

  if [ -n "$DISK_PATHS" ]; then
    # Paths must not contain spaces. The config format is whitespace-separated.
    set -f
    # shellcheck disable=SC2086
    set -- $DISK_PATHS
    set +f
    if [ $# -eq 0 ]; then
      lsc_emit CRIT disk "No paths to check" "DISK_PATHS is empty after parsing" "Set DISK_PATHS or leave it unset to scan filesystems."
    fi
    for mount in "$@"; do
      [ -n "$mount" ] || continue
      disk_one "$mount"
    done
  else
    local saw=0
    while IFS=$'\t' read -r target fstype; do
      [ -n "$target" ] || continue
      if lsc_skip_fstype "$fstype"; then
        continue
      fi
      saw=1
      disk_one "$target"
    done < <(df --output=target,fstype 2>/dev/null | awk 'NR>1 { printf "%s\t%s\n", $1, $2 }')
    if [ "$saw" -eq 0 ]; then
      evidence=$(lsc_add_line "$evidence" "detail=no_filesystems")
      overall=CRIT
    fi
  fi

  local summary recommendation
  case "$overall" in
    OK)
      summary="Filesystem usage and inodes are within thresholds."
      recommendation="No action required."
      ;;
    WARN)
      summary="One or more filesystems are at or above the warning threshold."
      recommendation="Free space or inodes on the mounts marked WARN before they reach the critical threshold."
      ;;
    *)
      summary="One or more filesystems are at or above the critical threshold."
      recommendation="Free space or inodes on the mounts marked CRIT. A full filesystem can stop services and logging."
      ;;
  esac
  lsc_emit "$overall" disk "$summary" "$evidence" "$recommendation"
}

main "$@"
