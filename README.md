# Solar Monitoring System for GivEnergy Inverter

This project provides a decoupled, code-driven solar monitoring system using a Raspberry Pi. The architecture is split into two independent sections:

1. **Application Stack** (`app-stack/`): Containerized services using Podman
2. **Infrastructure Automation** (`pi-infra/`): Ansible playbooks for Raspberry Pi provisioning

## Application Stack

The containerized services include:
- **Collector**: Python daemon that polls inverter data
- **InfluxDB**: Time-series database (v2.7)
- **Grafana**: Visualization dashboard

### Running Locally

1. Create `.env` file in `app-stack/` with:
```ini
INVERTER_IP=192.168.1.100
INFLUX_USER=admin
INFLUX_PASSWORD=your_secure_password
INFLUX_ORG=solar
INFLUX_BUCKET=solar_metrics
INFLUX_TOKEN=your_influx_token
GRAFANA_USER=admin
GRAFANA_PASSWORD=your_secure_password
```

2. Start the stack:
```bash
cd app-stack
podman-compose up -d --build
```

Access services at:
- InfluxDB: http://localhost:8086
- Grafana: http://localhost:3000

## Infrastructure Automation

Playbooks for Raspberry Pi provisioning:

### Provision Pi
```bash
ansible-playbook -i pi-infra/hosts.ini pi-infra/setup-pi.yml
```

### Deploy Application
```bash
ansible-playbook -i pi-infra/hosts.ini pi-infra/deploy-app.yml
```

> Replace IP in `hosts.ini` with your Pi's actual IP address

## Architecture
```
├── app-stack/
│   ├── collector/
│   │   ├── Containerfile
│   │   ├── main.py
│   │   └── requirements.txt
│   └── docker-compose.yml
├── pi-infra/
│   ├── deploy-app.yml
│   ├── hosts.ini
│   └── setup-pi.yml
└── README.md
```
