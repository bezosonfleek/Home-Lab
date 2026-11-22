# Homelab Monitoring Stack (Prometheus + Grafana + Exporters)

A self-hosted observability stack running on Docker Compose to collect host-level and container-level metrics, visualize resource usage in Grafana, and trigger alerts on threshold breaches.

> **Secure Remote Access:** Grafana binds strictly to `127.0.0.1:3000`. To share access without exposing ports publicly, see [grafana_ssh_setup.md](./grafana_ssh_setup.md).

---

## Directory Structure

```text
monitoring-stack/
├── README.md               # Stack documentation, dashboards, and alerting setup
├── grafana_ssh_setup.md    # Restricted SSH local port-forwarding guide
├── compose.yml             # Docker Compose service definitions
├── prometheus.yml          # Prometheus scrape targets and intervals
├── .env.example            # Template for required environment variables
└── .gitignore              # Ensures local .env secrets are never committed