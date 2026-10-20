# Lite test results

Date: 2026-10-20T04:05:43Z

## Tool versions

```
date: 2026-10-20T04:05:43Z
bash: GNU bash, version 5.2.37(1)-release (x86_64-pc-linux-gnu)
python: Python 3.13.5
docker: Docker version 26.1.5+dfsg1, build a72d7cd
shellcheck: ShellCheck - shell script analysis tool version: 0.11.0 license: GNU General Public License, version 3 website: https://www.shellcheck.net 
```

## Checks

```
PASS: lite files exist
PASS: lite README points at the full pack
PASS: lite license is MIT
PASS: full-only files are absent
PASS: bash -n lite scripts
PASS: shellcheck lite scripts
PASS: disk critical threshold
PASS: disk clear threshold
PASS: memory critical threshold
PASS: lite report is text only
PASS: lite exit matches overall (OK)
PASS: lite container demo writes a text report
PASS: lite demo exit matches overall (WARN)
PASS: lite screenshots are pngs
FAIL: anonymize leaked hostname or IP
```

## Command output

```
----- disk critical threshold exit=2 -----
STATUS=CRIT
CHECK=disk
SUMMARY=One or more filesystems are at or above the critical threshold.
EVIDENCE_BEGIN
thresholds used_warn=10 used_crit=20 inode_warn=100 inode_crit=100
mount=/ fstype=ext4 used=80% inodes=25% fs=/dev/vdb level=CRIT requested=/
EVIDENCE_END
RECOMMENDATION_BEGIN
Free space or inodes on the mounts marked CRIT. A full filesystem can stop services and logging.
RECOMMENDATION_END
----- disk clear threshold exit=0 -----
STATUS=OK
CHECK=disk
SUMMARY=Filesystem usage and inodes are within thresholds.
EVIDENCE_BEGIN
thresholds used_warn=100 used_crit=100 inode_warn=100 inode_crit=100
mount=/ fstype=ext4 used=80% inodes=25% fs=/dev/vdb level=OK requested=/
EVIDENCE_END
RECOMMENDATION_BEGIN
No action required.
RECOMMENDATION_END
----- memory critical threshold exit=2 -----
STATUS=CRIT
CHECK=memory
SUMMARY=Memory or swap is at or above the critical threshold.
EVIDENCE_BEGIN
thresholds mem_warn=1 mem_crit=2 swap_warn=100 swap_crit=100
mem_total_kb=16386368 mem_available_kb=7239100 mem_used_pct=55 mem_level=CRIT
swap_total_kb=0 swap_free_kb=0 swap_used_pct=n/a swap_level=OK
dmesg=readable
oom_lines=0
EVIDENCE_END
RECOMMENDATION_BEGIN
Add memory, reduce the workload, or stop a leaking process. A host this low on memory can start killing processes. Swap is not configured; that is reported and is not by itself a warning.
RECOMMENDATION_END
----- lite run_all exit=0 -----
Overall: OK
Wrote /tmp/tmp.xsdDvcHyFl/report/health.txt
----- lite health.txt -----
Linux Server Health Check (lite)
Pack: lite
Generated (UTC): 2026-10-20T04:05:21Z
Host: demo-host
Overall: OK

------------------------------------------------------------
Check: disk
Status: OK
Summary: Filesystem usage and inodes are within thresholds.
Evidence:
    thresholds used_warn=100 used_crit=100 inode_warn=100 inode_crit=100
    mount=/ fstype=ext4 used=80% inodes=25% fs=/dev/vdb level=OK requested=/
Recommendation:
    No action required.

------------------------------------------------------------
Check: memory
Status: OK
Summary: Memory is within thresholds and dmesg shows no OOM lines.
Evidence:
    thresholds mem_warn=80 mem_crit=95 swap_warn=50 swap_crit=80
    mem_total_kb=16386368 mem_available_kb=7212060 mem_used_pct=55 mem_level=OK
    swap_total_kb=0 swap_free_kb=0 swap_used_pct=n/a swap_level=OK
    dmesg=readable
    oom_lines=0
Recommendation:
    No action required. Swap is not configured; that is reported and is not by itself a warning.

----- lite demo exit=1 -----
Overall: WARN
Wrote /out/health.txt
LSC_EXIT=1
===== health.txt =====
Linux Server Health Check (lite)
Pack: lite
Generated (UTC): 2026-10-20T04:05:43Z
Host: demo-host
Overall: WARN

------------------------------------------------------------
Check: disk
Status: WARN
Summary: One or more filesystems are at or above the warning threshold.
Evidence:
    thresholds used_warn=80 used_crit=90 inode_warn=80 inode_crit=90
    mount=/ fstype=ext4 used=80% inodes=25% fs=/dev/vdb level=WARN requested=/
Recommendation:
    Free space or inodes on the mounts marked WARN before they reach the critical threshold.

------------------------------------------------------------
Check: memory
Status: OK
Summary: Memory is within thresholds. dmesg could not be read.
Evidence:
    thresholds mem_warn=85 mem_crit=95 swap_warn=60 swap_crit=90
    mem_total_kb=16386368 mem_available_kb=7265836 mem_used_pct=55 mem_level=OK
    swap_total_kb=0 swap_free_kb=0 swap_used_pct=n/a swap_level=OK
    dmesg=unreadable
    oom_lines=0
Recommendation:
    No memory action required. To include OOM history, allow the user to read dmesg or grant passwordless sudo for dmesg only. Swap is not configured; that is reported and is not by itself a warning.

----- lite demo stderr -----
apt-get failed
screenshots/01-text-report.png (1012, 1524) PNG
screenshots/02-check-output.png (1012, 844) PNG
FAILS=0
leak lines:
/tmp/u_linux-server-check-lite/.git/logs/refs/remotes/origin/HEAD:1:0000000000000000000000000000000000000000 38fd728043009dc6e09910157cff60cbec47083b box <box@demo-host.(none)> 1792469042 +0800	clone: from https://github.com/caoyadong888-wq/linux-server-check-lite.git
/tmp/u_linux-server-check-lite/.git/logs/refs/heads/main:1:0000000000000000000000000000000000000000 38fd728043009dc6e09910157cff60cbec47083b box <box@demo-host.(none)> 1792469042 +0800	clone: from https://github.com/caoyadong888-wq/linux-server-check-lite.git
/tmp/u_linux-server-check-lite/.git/logs/HEAD:1:0000000000000000000000000000000000000000 38fd728043009dc6e09910157cff60cbec47083b box <box@demo-host.(none)> 1792469042 +0800	clone: from https://github.com/caoyadong888-wq/linux-server-check-lite.git
```
