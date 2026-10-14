Aquí tienes el `README.md` completo en inglés, redactado con rigor técnico, justificación de arquitectura y explicaciones estadísticas para que destaque como un proyecto de observabilidad de nivel profesional en GitHub:

```markdown
# Linux RAM & Process Monitor

A lightweight, on-demand observability stack engineered to monitor, persist, and statistically analyze system memory (RAM/Swap) and per-process memory consumption on Linux.

Built on **Rootless Podman**, **VictoriaMetrics**, **Prometheus Exporters**, and **Grafana**, this project implements full Infrastructure-as-Code (IaC) provisioning: clone the repository, run one command, and get instant real-time and historical dashboards without manual setup.

---

## Architecture Overview


```

```
                  +---------------------------------------+
                  |               Linux Host              |
                  +---------------------------------------+
                              |                |
                /proc/meminfo |                | /proc/[pid]
                /proc/vmstat  |                |
                              v                v
                   +----------------+   +-------------------+
                   | node-exporter  |   | process-exporter  |
                   |  (Port 9100)   |   |   (Port 9256)     |
                   +----------------+   +-------------------+
                              ^                ^
                              | Scrape (5s)    | Scrape (5s)
                   +----------------------------------------+
                   |            VictoriaMetrics             |
                   |              (Port 8428)               |
                   |   - Fast ingestion & high compression  |
                   |   - PromQL / MetricsQL engine          |
                   |   - Persistent volume (/storage)       |
                   +----------------------------------------+
                                       ^
                                       | Query (Proxy)
                   +----------------------------------------+
                   |              Grafana OSS               |
                   |              (Port 3000)               |
                   |   - Auto-provisioned Datasource        |
                   |   - Auto-provisioned Dashboard         |
                   +----------------------------------------+

```

```

### Core Design Decisions

- **VictoriaMetrics instead of Vanilla Prometheus:** VictoriaMetrics requires up to 10x less RAM and CPU while achieving superior disk compression ratios for time-series data. It natively parses PromQL and extends it with MetricsQL subquery support without requiring complex recording rules.
- **Rootless Podman instead of Docker Daemon:** Runs entirely in unprivileged user space. Eliminates persistent root daemons running in the background, matching enterprise security standards on distributions like Fedora, RHEL, and Arch.
- **On-Demand Lifecycle:** Designed to be toggled on/off at will. When stopped (`make stop`), CPU and memory utilization drop to **0%**, while collected historical metrics remain safely stored on disk.
- **Strict Localhost Binding (`127.0.0.1`):** While running in `network_mode: host` to access kernel host metrics directly, all services are strictly bound to `127.0.0.1` to prevent unwanted exposure across local networks (e.g., public Wi-Fi or local firewalld workstation zones).

---

## Statistical Methodology & MetricsQL

Standard system monitors (like basic top/htop) only display current snapshot utilization. This stack captures trends, volatility, and distribution across custom observation windows.

### 1. Actual Used RAM vs. Free RAM
In Linux, unused RAM is wasted RAM. The Linux kernel aggressively uses free memory for file system caching (`buffers` and `cached`). Therefore, calculating used memory as `Total - Free` produces artificially inflated usage figures.

This project calculates memory pressure using `MemAvailable`:
$$\text{RAM Used (GB)} = \frac{\text{MemTotal} - \text{MemAvailable}}{1024^3}$$

### 2. Statistical Aggregations Over Dynamic Range (`[$__range]`)
When you inspect a 1-hour build task, a gaming session, or an 8-hour workday, the dashboard evaluates the entire window dynamically:

| Metric | MetricsQL / PromQL Query | Purpose |
| :--- | :--- | :--- |
| **Current Used %** | `100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)` | Real-time gauge of memory saturation. |
| **Average (Mean)** | `avg_over_time((node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)[$__range]) / 1024^3` | Baseline memory footprint of your workflow. |
| **Peak Usage (Max)** | `max_over_time((node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)[$__range]) / 1024^3` | Absolute worst-case memory pressure observed. |
| **95th Percentile (P95)**| `quantile_over_time(0.95, (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)[$__range]) / 1024^3` | Industry-standard SRE metric. Filters out temporary 1-second spikes to show the true sustained ceiling 95% of the time. |
| **Standard Deviation** | `stddev_over_time((node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)[$__range]) / 1024^3` | Workload volatility indicator. High values mean frequent opening/closing of memory-heavy workloads. |

### 3. Per-Process Attribution (RSS)
Using `process-exporter`, memory is broken down by executable groups:
```promql
topk(10, namedprocess_namegroup_memory_bytes{memtype="resident"}) / 1024^2

```

This isolates the Resident Set Size (RSS)—the actual physical RAM occupied by each process group (e.g., browser processes, desktop shell, IDEs) in megabytes.

---

## Repository Structure

```text
linux-ram-monitor/
├── compose.yml                 # Multi-container rootless Podman definition
├── Makefile                    # Standard operational targets (up, stop, start, check)
├── process-exporter.yml        # Process name matching and aggregation rules
├── scrape.yml                  # VictoriaMetrics scrape targets (5s intervals)
├── provisioning/
│   ├── dashboards/
│   │   ├── provider.yml        # Grafana dashboard provider definition
│   │   └── ram-overview.json   # Pre-configured Grafana dashboard JSON
│   └── datasources/
│       └── victoria.yml        # Auto-provisioned VictoriaMetrics connection
└── README.md

```

---

## Prerequisites

* Any modern Linux distribution (Fedora, Ubuntu, Debian, Arch, openSUSE).
* `podman`, `podman-compose`, and `make`.

#### Fedora:

```bash
sudo dnf install -y podman podman-compose make

```

#### Ubuntu / Debian:

```bash
sudo apt update && sudo apt install -y podman podman-compose make

```

#### Arch Linux:

```bash
sudo pacman -S podman podman-compose make

```

---

## Quick Start

### 1. Clone & Launch

```bash
git clone [https://github.com/YOUR_USERNAME/linux-ram-monitor.git](https://github.com/YOUR_USERNAME/linux-ram-monitor.git)
cd linux-ram-monitor
make up

```

### 2. Verify Targets

Wait 5 seconds for initialization, then verify that both exporters are reporting healthy scrapes:

```bash
make check

```

*Expected output: Two `"health":"up"` confirmations followed by `Targets OK`.*

### 3. Access Dashboard

Navigate to `http://127.0.0.1:3000` in your browser:

* **Username:** `admin`
* **Password:** `admin` *(can be skipped on first prompt)*
* Go to **Dashboards** → **Linux RAM & Process Monitor**.

---

## Everyday Usage & Lifecycle Management

You do not need to keep Grafana open while working. VictoriaMetrics will silently record metrics in the background at an imperceptible footprint (~30 MB RAM).

| Command | Action |
| --- | --- |
| `make start` | Resumes metric collection for your current working session. |
| `make stop` | Freezes containers. Utilization drops to 0% CPU and 0% RAM. Data persists. |
| `make status` | Displays container health and uptime status. |
| `make logs` | Streams live logs from all containers. |
| `make check` | Validates target health against VictoriaMetrics API. |
| `make down` | Tears down containers (named volumes with data are still retained). |

### Recommended Terminal Aliases

Add these shortcuts to your shell configuration (`~/.bashrc` or `~/.zshrc`):

```bash
alias ram-on="make -C ~/linux-ram-monitor start"
alias ram-off="make -C ~/linux-ram-monitor stop"
alias ram-status="make -C ~/linux-ram-monitor status"
alias ram-ui="xdg-open [http://127.0.0.1:3000](http://127.0.0.1:3000)"

```

---

## Security & SELinux Notes

* **SELinux compatibility:** On systems running SELinux in Enforcing mode (Fedora/RHEL), host mounts are isolated using the `:ro,rslave` propagation and `label=disable` container policies, granting read-only access to `/proc` and host metrics without modifying host security contexts.
* **Smaps parsing disabled:** `process-exporter` runs with `--gather-smaps=false`. This prevents permission denied errors when inspecting root processes from an unprivileged user namespace and drastically lowers collection CPU usage.

---

## License

Distributed under the MIT License. Feel free to fork, adapt, and use it for personal monitoring or infrastructure benchmarking.

```

Para actualizar tu archivo actual con este contenido directamente desde tu terminal, corre:

```bash
cat << 'EOF' > ~/linux-ram-monitor/README.md
# Linux RAM & Process Monitor

A lightweight, on-demand observability stack engineered to monitor, persist, and statistically analyze system memory (RAM/Swap) and per-process memory consumption on Linux.

Built on **Rootless Podman**, **VictoriaMetrics**, **Prometheus Exporters**, and **Grafana**, this project implements full Infrastructure-as-Code (IaC) provisioning: clone the repository, run one command, and get instant real-time and historical dashboards without manual setup.

---

## Architecture Overview


```

```
                  +---------------------------------------+
                  |               Linux Host              |
                  +---------------------------------------+
                              |                |
                /proc/meminfo |                | /proc/[pid]
                /proc/vmstat  |                |
                              v                v
                   +----------------+   +-------------------+
                   | node-exporter  |   | process-exporter  |
                   |  (Port 9100)   |   |   (Port 9256)     |
                   +----------------+   +-------------------+
                              ^                ^
                              | Scrape (5s)    | Scrape (5s)
                   +----------------------------------------+
                   |            VictoriaMetrics             |
                   |              (Port 8428)               |
                   |   - Fast ingestion & high compression  |
                   |   - PromQL / MetricsQL engine          |
                   |   - Persistent volume (/storage)       |
                   +----------------------------------------+
                                       ^
                                       | Query (Proxy)
                   +----------------------------------------+
                   |              Grafana OSS               |
                   |              (Port 3000)               |
                   |   - Auto-provisioned Datasource        |
                   |   - Auto-provisioned Dashboard         |
                   +----------------------------------------+

```

```

### Core Design Decisions

- **VictoriaMetrics instead of Vanilla Prometheus:** VictoriaMetrics requires up to 10x less RAM and CPU while achieving superior disk compression ratios for time-series data. It natively parses PromQL and extends it with MetricsQL subquery support without requiring complex recording rules.
- **Rootless Podman instead of Docker Daemon:** Runs entirely in unprivileged user space. Eliminates persistent root daemons running in the background, matching enterprise security standards on distributions like Fedora, RHEL, and Arch.
- **On-Demand Lifecycle:** Designed to be toggled on/off at will. When stopped (`make stop`), CPU and memory utilization drop to **0%**, while collected historical metrics remain safely stored on disk.
- **Strict Localhost Binding (`127.0.0.1`):** While running in `network_mode: host` to access kernel host metrics directly, all services are strictly bound to `127.0.0.1` to prevent unwanted exposure across local networks (e.g., public Wi-Fi or local firewalld workstation zones).

---

## Statistical Methodology & MetricsQL

Standard system monitors (like basic top/htop) only display current snapshot utilization. This stack captures trends, volatility, and distribution across custom observation windows.

### 1. Actual Used RAM vs. Free RAM
In Linux, unused RAM is wasted RAM. The Linux kernel aggressively uses free memory for file system caching (`buffers` and `cached`). Therefore, calculating used memory as `Total - Free` produces artificially inflated usage figures.

This project calculates memory pressure using `MemAvailable`:
$$\text{RAM Used (GB)} = \frac{\text{MemTotal} - \text{MemAvailable}}{1024^3}$$

### 2. Statistical Aggregations Over Dynamic Range (`[$__range]`)
When you inspect a 1-hour build task, a gaming session, or an 8-hour workday, the dashboard evaluates the entire window dynamically:

| Metric | MetricsQL / PromQL Query | Purpose |
| :--- | :--- | :--- |
| **Current Used %** | `100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)` | Real-time gauge of memory saturation. |
| **Average (Mean)** | `avg_over_time((node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)[$__range]) / 1024^3` | Baseline memory footprint of your workflow. |
| **Peak Usage (Max)** | `max_over_time((node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)[$__range]) / 1024^3` | Absolute worst-case memory pressure observed. |
| **95th Percentile (P95)**| `quantile_over_time(0.95, (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)[$__range]) / 1024^3` | Industry-standard SRE metric. Filters out temporary 1-second spikes to show the true sustained ceiling 95% of the time. |
| **Standard Deviation** | `stddev_over_time((node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)[$__range]) / 1024^3` | Workload volatility indicator. High values mean frequent opening/closing of memory-heavy workloads. |

### 3. Per-Process Attribution (RSS)
Using `process-exporter`, memory is broken down by executable groups:
```promql
topk(10, namedprocess_namegroup_memory_bytes{memtype="resident"}) / 1024^2

```

This isolates the Resident Set Size (RSS)—the actual physical RAM occupied by each process group (e.g., browser processes, desktop shell, IDEs) in megabytes.

---

## Repository Structure

```text
linux-ram-monitor/
├── compose.yml                 # Multi-container rootless Podman definition
├── Makefile                    # Standard operational targets (up, stop, start, check)
├── process-exporter.yml        # Process name matching and aggregation rules
├── scrape.yml                  # VictoriaMetrics scrape targets (5s intervals)
├── provisioning/
│   ├── dashboards/
│   │   ├── provider.yml        # Grafana dashboard provider definition
│   │   └── ram-overview.json   # Pre-configured Grafana dashboard JSON
│   └── datasources/
│       └── victoria.yml        # Auto-provisioned VictoriaMetrics connection
└── README.md

```

---

## Prerequisites

* Any modern Linux distribution (Fedora, Ubuntu, Debian, Arch, openSUSE).
* `podman`, `podman-compose`, and `make`.

#### Fedora:

```bash
sudo dnf install -y podman podman-compose make

```

#### Ubuntu / Debian:

```bash
sudo apt update && sudo apt install -y podman podman-compose make

```

#### Arch Linux:

```bash
sudo pacman -S podman podman-compose make

```

---

## Quick Start

### 1. Clone & Launch

```bash
git clone [https://github.com/YOUR_USERNAME/linux-ram-monitor.git](https://github.com/YOUR_USERNAME/linux-ram-monitor.git)
cd linux-ram-monitor
make up

```

### 2. Verify Targets

Wait 5 seconds for initialization, then verify that both exporters are reporting healthy scrapes:

```bash
make check

```

*Expected output: Two `"health":"up"` confirmations followed by `Targets OK`.*

### 3. Access Dashboard

Navigate to `http://127.0.0.1:3000` in your browser:

* **Username:** `admin`
* **Password:** `admin` *(can be skipped on first prompt)*
* Go to **Dashboards** -> **Linux RAM & Process Monitor**.

---

## Everyday Usage & Lifecycle Management

You do not need to keep Grafana open while working. VictoriaMetrics will silently record metrics in the background at an imperceptible footprint (~30 MB RAM).

| Command | Action |
| --- | --- |
| `make start` | Resumes metric collection for your current working session. |
| `make stop` | Freezes containers. Utilization drops to 0% CPU and 0% RAM. Data persists. |
| `make status` | Displays container health and uptime status. |
| `make logs` | Streams live logs from all containers. |
| `make check` | Validates target health against VictoriaMetrics API. |
| `make down` | Tears down containers (named volumes with data are still retained). |

### Recommended Terminal Aliases

Add these shortcuts to your shell configuration (`~/.bashrc` or `~/.zshrc`):

```bash
alias ram-on="make -C ~/linux-ram-monitor start"
alias ram-off="make -C ~/linux-ram-monitor stop"
alias ram-status="make -C ~/linux-ram-monitor status"
alias ram-ui="xdg-open [http://127.0.0.1:3000](http://127.0.0.1:3000)"

```

---

## Security & SELinux Notes

* **SELinux compatibility:** On systems running SELinux in Enforcing mode (Fedora/RHEL), host mounts are isolated using the `:ro,rslave` propagation and `label=disable` container policies, granting read-only access to `/proc` and host metrics without modifying host security contexts.
* **Smaps parsing disabled:** `process-exporter` runs with `--gather-smaps=false`. This prevents permission denied errors when inspecting root processes from an unprivileged user namespace and drastically lowers collection CPU usage.

---

## License

Distributed under the MIT License. Feel free to fork, adapt, and use it for personal monitoring or infrastructure benchmarking.
EOF

```

```