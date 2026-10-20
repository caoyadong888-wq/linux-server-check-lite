#!/usr/bin/env bash
# Shared helpers for read-only health checks.
# Functions that call lsc_emit exit the process. They do not change the system.

# shellcheck shell=bash
# Config keys and record fields are read by the scripts that source this file.
# shellcheck disable=SC2034

export LC_ALL=C

lsc_emit() {
  local status=$1
  local check=$2
  local summary=$3
  local evidence=$4
  local recommendation=$5
  printf 'STATUS=%s\n' "$status"
  printf 'CHECK=%s\n' "$check"
  printf 'SUMMARY=%s\n' "$summary"
  printf 'EVIDENCE_BEGIN\n'
  printf '%s\n' "$evidence"
  printf 'EVIDENCE_END\n'
  printf 'RECOMMENDATION_BEGIN\n'
  printf '%s\n' "$recommendation"
  printf 'RECOMMENDATION_END\n'
  case "$status" in
    OK) exit 0 ;;
    WARN) exit 1 ;;
    CRIT) exit 2 ;;
    *) exit 2 ;;
  esac
}

lsc_rank() {
  case "$1" in
    OK) printf '0\n' ;;
    WARN) printf '1\n' ;;
    CRIT) printf '2\n' ;;
    *) printf '2\n' ;;
  esac
}

lsc_worse() {
  local a=$1
  local b=$2
  local ra rb
  ra=$(lsc_rank "$a")
  rb=$(lsc_rank "$b")
  if [ "$rb" -gt "$ra" ]; then
    printf '%s\n' "$b"
  else
    printf '%s\n' "$a"
  fi
}

lsc_pct_level() {
  local pct=$1
  local warn=$2
  local crit=$3
  if [ "$pct" -ge "$crit" ]; then
    printf 'CRIT\n'
  elif [ "$pct" -ge "$warn" ]; then
    printf 'WARN\n'
  else
    printf 'OK\n'
  fi
}

lsc_norm_uint() {
  local v=$1
  case "$v" in
    ''|*[!0-9]*) return 1 ;;
  esac
  printf '%s\n' "$((10#$v))"
}

# Assign a normalized integer to a known config variable in the caller scope.
# Must be called directly, not inside $(...), because a bad value exits.
lsc_require_uint() {
  local _name=$1
  local _value=$2
  local _check=$3
  local _max=${4:-}
  local _norm
  if ! _norm=$(lsc_norm_uint "$_value"); then
    lsc_emit CRIT "$_check" "Invalid $_name" "$_name=$_value" "Set $_name to a non-negative integer."
  fi
  if [ -n "$_max" ] && [ "$_norm" -gt "$_max" ]; then
    lsc_emit CRIT "$_check" "Invalid $_name" "$_name=$_norm max=$_max" "Set $_name to an integer from 0 through $_max."
  fi
  case "$_name" in
    DISK_WARN_PCT) DISK_WARN_PCT=$_norm ;;
    DISK_CRIT_PCT) DISK_CRIT_PCT=$_norm ;;
    INODE_WARN_PCT) INODE_WARN_PCT=$_norm ;;
    INODE_CRIT_PCT) INODE_CRIT_PCT=$_norm ;;
    MEM_WARN_PCT) MEM_WARN_PCT=$_norm ;;
    MEM_CRIT_PCT) MEM_CRIT_PCT=$_norm ;;
    SWAP_WARN_PCT) SWAP_WARN_PCT=$_norm ;;
    SWAP_CRIT_PCT) SWAP_CRIT_PCT=$_norm ;;
    CERT_WARN_DAYS) CERT_WARN_DAYS=$_norm ;;
    CERT_CRIT_DAYS) CERT_CRIT_DAYS=$_norm ;;
    CERT_PORT) CERT_PORT=$_norm ;;
    BACKUP_STALE_HOURS) BACKUP_STALE_HOURS=$_norm ;;
    BACKUP_MIN_BYTES) BACKUP_MIN_BYTES=$_norm ;;
    *)
      lsc_emit CRIT "$_check" "Internal config error" "key=$_name" "Report this as a script bug."
      ;;
  esac
}

lsc_require_ordered() {
  local check=$1
  local warn_name=$2
  local warn=$3
  local crit_name=$4
  local crit=$5
  if [ "$warn" -gt "$crit" ]; then
    lsc_emit CRIT "$check" "Invalid thresholds" "$warn_name=$warn $crit_name=$crit" "Set the warning threshold at or below the critical threshold."
  fi
}

lsc_is_float() {
  local v=$1
  case "$v" in
    ''|*[!0-9.]*) return 1 ;;
    *.*.*) return 1 ;;
    .) return 1 ;;
  esac
  case "$v" in
    *[0-9]*) return 0 ;;
    *) return 1 ;;
  esac
}

lsc_skip_fstype() {
  case "$1" in
    devtmpfs|tmpfs|squashfs|overlay|overlayfs|devfs|efivarfs|proc|sysfs|devpts|cgroup|cgroup2|securityfs|pstore|bpf|debugfs|tracefs|fusectl|mqueue|hugetlbfs|nsfs|autofs|binfmt_misc|configfs|rpc_pipefs|selinuxfs|ramfs)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

lsc_sanitize() {
  printf '%s' "$1" | tr -d '\000-\010\013\014\016-\037'
}

lsc_add_line() {
  local current=$1
  local extra=$2
  extra=$(lsc_sanitize "$extra")
  if [ -n "$current" ]; then
    printf '%s\n%s\n' "$current" "$extra"
  else
    printf '%s\n' "$extra"
  fi
}

lsc_read_record() {
  local file=$1
  local mode="" line
  LSC_R_STATUS=""
  LSC_R_CHECK=""
  LSC_R_SUMMARY=""
  LSC_R_EVIDENCE=""
  LSC_R_RECOMMENDATION=""
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      STATUS=*) LSC_R_STATUS=${line#STATUS=} ;;
      CHECK=*) LSC_R_CHECK=${line#CHECK=} ;;
      SUMMARY=*) LSC_R_SUMMARY=${line#SUMMARY=} ;;
      EVIDENCE_BEGIN) mode=e ;;
      EVIDENCE_END) mode="" ;;
      RECOMMENDATION_BEGIN) mode=r ;;
      RECOMMENDATION_END) mode="" ;;
      *)
        if [ "$mode" = e ]; then
          if [ -n "$LSC_R_EVIDENCE" ]; then
            LSC_R_EVIDENCE="${LSC_R_EVIDENCE}"$'\n'"${line}"
          else
            LSC_R_EVIDENCE=$line
          fi
        elif [ "$mode" = r ]; then
          if [ -n "$LSC_R_RECOMMENDATION" ]; then
            LSC_R_RECOMMENDATION="${LSC_R_RECOMMENDATION}"$'\n'"${line}"
          else
            LSC_R_RECOMMENDATION=$line
          fi
        fi
        ;;
    esac
  done <"$file"
}

# lsc_load_config FILE CHECK
# Assigns known keys in the caller scope. May exit through lsc_emit.
lsc_load_config() {
  local file=$1
  local check=$2
  local line key val
  if [ ! -f "$file" ]; then
    lsc_emit CRIT "$check" "Config file not found" "path=$file" "Pass an existing file to --config."
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}
    line=${line#"${line%%[![:space:]]*}"}
    case "$line" in
      ''|\#*) continue ;;
    esac
    case "$line" in
      *=*) ;;
      *)
        lsc_emit CRIT "$check" "Invalid config line" "$line" "Use KEY=value. Put comments on their own line starting with #."
        ;;
    esac
    key=${line%%=*}
    val=${line#*=}
    key=${key#"${key%%[![:space:]]*}"}
    key=${key%"${key##*[![:space:]]}"}
    val=${val#"${val%%[![:space:]]*}"}
    val=${val%"${val##*[![:space:]]}"}
    case "$val" in
      \"*\") val=${val#\"}; val=${val%\"} ;;
      \'*\') val=${val#\'}; val=${val%\'} ;;
    esac
    case "$key" in
      DISK_WARN_PCT) DISK_WARN_PCT=$val ;;
      DISK_CRIT_PCT) DISK_CRIT_PCT=$val ;;
      INODE_WARN_PCT) INODE_WARN_PCT=$val ;;
      INODE_CRIT_PCT) INODE_CRIT_PCT=$val ;;
      DISK_PATHS) DISK_PATHS=$val ;;
      MEM_WARN_PCT) MEM_WARN_PCT=$val ;;
      MEM_CRIT_PCT) MEM_CRIT_PCT=$val ;;
      SWAP_WARN_PCT) SWAP_WARN_PCT=$val ;;
      SWAP_CRIT_PCT) SWAP_CRIT_PCT=$val ;;
      SERVICE_UNITS) SERVICE_UNITS=$val ;;
      CERT_DOMAINS) CERT_DOMAINS=$val ;;
      CERT_WARN_DAYS) CERT_WARN_DAYS=$val ;;
      CERT_CRIT_DAYS) CERT_CRIT_DAYS=$val ;;
      CERT_FILES) CERT_FILES=$val ;;
      CERT_PORT) CERT_PORT=$val ;;
      BACKUP_DIRS) BACKUP_DIRS=$val ;;
      BACKUP_STALE_HOURS) BACKUP_STALE_HOURS=$val ;;
      BACKUP_MIN_BYTES) BACKUP_MIN_BYTES=$val ;;
      LOAD_WARN_PER_CPU) LOAD_WARN_PER_CPU=$val ;;
      LOAD_CRIT_PER_CPU) LOAD_CRIT_PER_CPU=$val ;;
      *)
        printf 'warning: ignoring unknown config key %s\n' "$key" >&2
        ;;
    esac
  done <"$file"
}
