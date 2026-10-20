# Linux Server Health Check (Lite)

A free preview of the read-only Linux server health check. This subset checks disk usage, inodes, memory, and swap, then writes a text report. It does not change the system.

## English

### What it is

`checks/disk.sh` reads filesystem usage and inode use. `checks/memory.sh` reads `/proc/meminfo` and, when dmesg is readable, looks for OOM killer lines. `run_all.sh` writes `report/health.txt` with status OK, WARN, or CRIT, evidence, and a recommendation. The exit code is the worst status: `0` OK, `1` WARN, `2` CRIT.

### Quick start

```bash
cp config.example.conf config.conf
bash run_all.sh --config config.conf --out report
```

### One-click demo

```bash
make demo
```

or:

```bash
./demo.sh
```

The demo starts `debian:stable-slim`, installs `procps` in the container, and runs the two checks against that container.

### Deliverables / 交付物清单

- `checks/disk.sh`
- `checks/memory.sh`
- `run_all.sh` (text report only)
- `lib/common.sh`
- `config.example.conf` and `demo/demo.conf`
- `demo.sh`, `demo/inside.sh`, `Makefile`
- `tests/run_tests.sh`
- `screenshots/`
- `.shellcheckrc`
- `README.md` and `LICENSE` (MIT)

### Estimated setup time / 预计部署时间

About 2 minutes. Copy the example config and run `bash run_all.sh --config config.conf`.

### 预计交付时间 / Estimated delivery time

Download is instant after payment. Setup on your own machine is about 2 minutes: copy the example config and run `bash run_all.sh --config config.conf`. A custom setup service, if you order one, takes 1–2 business days.

付款后立即下载。自行部署大约 2 分钟：复制示例配置并运行检查。如果需要代为部署，定制服务为 1–2 个工作日。

### Requirements

- Linux with bash 4 or newer, GNU coreutils, and awk
- Docker is optional and is used by `make demo`
- sudo is optional and is used only as `sudo -n dmesg` when dmesg is not readable
- Root is not required

### License

MIT. See `LICENSE`.

## 中文说明

### 这是什么

这是只读 Linux 服务器健康检查的免费预览。`checks/disk.sh` 查看磁盘使用率和 inode。`checks/memory.sh` 读取内存和交换分区，并在 dmesg 可读时查找 OOM 记录。`run_all.sh` 只写出文本报告 `report/health.txt`，包含 OK / WARN / CRIT、证据和建议。退出码等于最差状态：`0` OK，`1` WARN，`2` CRIT。脚本不修改系统。

### 快速开始

```bash
cp config.example.conf config.conf
bash run_all.sh --config config.conf --out report
```

### 一键演示

```bash
make demo
```

或：

```bash
./demo.sh
```

演示会启动 `debian:stable-slim`，在容器里安装 `procps`，然后对容器自身做磁盘和内存检查。

### 交付物清单 / Deliverables

- `checks/disk.sh`
- `checks/memory.sh`
- `run_all.sh`（仅文本报告）
- `lib/common.sh`
- `config.example.conf` 和 `demo/demo.conf`
- `demo.sh`、`demo/inside.sh`、`Makefile`
- `tests/run_tests.sh`
- `screenshots/`
- `.shellcheckrc`
- `README.md` 和 `LICENSE`（MIT）

### Estimated setup time / 预计部署时间

大约 2 分钟。复制示例配置，运行 `bash run_all.sh --config config.conf`。

### 预计交付时间 / Estimated delivery time

付款后立即下载。自行部署大约 2 分钟：复制示例配置，运行 `bash run_all.sh --config config.conf`。如果需要代为部署，定制服务为 1–2 个工作日。

Download is instant after payment. Setup on your own machine is about 2 minutes. A custom setup service takes 1–2 business days.

### 运行环境

- Linux，bash 4 或更新版本，GNU coreutils 和 awk
- Docker 可选，只用于 `make demo`
- sudo 可选，仅在 dmesg 不可读时使用 `sudo -n dmesg`
- 不需要 root

### 许可证

MIT。见 `LICENSE`。

## Full version / 完整版

The paid pack adds the checks and reports that this preview leaves out. The product page is GUMROAD_URL.

It also pairs with the $9 n8n DevOps Automation Pack: https://caoyadong.gumroad.com/l/yvmcqj

Only in the full version:

- `checks/services.sh` — systemd failed units, or a configured process list when systemd is not running
- `checks/cert.sh` — TLS expiry for domain names via openssl, and local certificate files
- `checks/backup.sh` — newest backup file age and size against a stale threshold
- `checks/load.sh` — load average divided by CPU count, and uptime
- Markdown report `report/health.md`
- HTML report `report/health.html`
- `marketing/` listing and cover images
- `GUMROAD_LISTING.md`
- `CHANGELOG.md`

完整版在本预览之外增加上述检查和报告。商品页是 GUMROAD_URL。

另有 9 美元的 n8n DevOps Automation Pack：https://caoyadong.gumroad.com/l/yvmcqj

只在完整版中提供：

- `checks/services.sh`：systemd 失败单元；没有 systemd 时按配置的进程名检查
- `checks/cert.sh`：用 openssl 检查域名证书到期时间，以及本地证书文件
- `checks/backup.sh`：备份目录中最新文件的年龄和大小，对照过期阈值
- `checks/load.sh`：负载除以 CPU 数，以及开机时间
- Markdown 报告 `report/health.md`
- HTML 报告 `report/health.html`
- `marketing/` 商品文案和封面图
- `GUMROAD_LISTING.md`
- `CHANGELOG.md`
