# givmedagraphs

Solar monitoring for a GivEnergy hybrid inverter. A collector polls the inverter over Modbus, stores the readings in InfluxDB, and Grafana shows them on a provisioned **Battery** dashboard.

```
inverter (Modbus, port 8899) ──> collector ──> InfluxDB ──> Grafana
```

## Components

| Service | Image | Port | Purpose |
| :--- | :--- | :--- | :--- |
| `collector` | built from `app-stack/collector` | – | Python daemon. Polls the inverter every 5 seconds and writes an `inverter` measurement to InfluxDB. |
| `influxdb` | `influxdb:latest` (v2) | 8086 | Time-series storage. |
| `grafana` | `grafana-oss:latest` | 3000 | Dashboards. The InfluxDB datasource and the Battery dashboard are provisioned automatically. |

All images are pulled from a registry set by `REGISTRY` (see [Deployment model](#deployment-model)).

### Collected fields

`p_pv1`, `p_pv2`, `p_pv_combined`, `p_battery`, `p_grid_out`, `p_load_demand`, `battery_soc`, `v_battery`, `i_battery`, `v_pv1`, `v_pv2`, `v_ac1`, `f_ac1`, `t_inverter_heatsink`, `e_pv_generation_today`, `e_grid_out_day`, `e_grid_in_day`.

`app-stack/collector/fields.md` documents the full set of fields the inverter exposes.

### Dashboard

The **Battery** dashboard is in the *Solar* folder and is also Grafana's home page. It has these panels:

- Power & Charge Overview
- Current Charge
- PV Generation
- Battery Power
- House Load

## Repository layout

```
app-stack/
├── docker-compose.yml        # the three services
├── startup.sh                # start (or, with --deploy, install) the stack
├── .env                      # configuration (see below)
├── collector/                # Containerfile, main.py, requirements.txt, fields.md
└── grafana/provisioning/     # datasource + dashboard provisioning
    ├── datasources/influxdb.yml
    └── dashboards/{dashboards.yml, json/battery.json}
deploy/
├── build-to-registry.sh      # local registry + build/mirror all images
├── run-local.sh              # build-to-registry.sh, then startup.sh
└── deploy-to-pi.sh           # build for arm64 and install on a Raspberry Pi
```

## Requirements

- Docker with the `docker compose` plugin (v2), `curl`, and `bash`.
- Network access to the inverter on port 8899.
- For Pi deployment: `ssh <pi-host>` works without a password prompt, the Pi has Docker and the `docker compose` plugin, and your user there has `sudo`.

## Configuration

Settings live in `app-stack/.env`:

| Variable | Description |
| :--- | :--- |
| `INVERTER_IP` | IP address of the inverter. |
| `INFLUX_USER`, `INFLUX_PASSWORD` | InfluxDB admin login. |
| `INFLUX_ORG`, `INFLUX_BUCKET` | InfluxDB organisation and bucket. |
| `INFLUX_TOKEN` | InfluxDB admin API token, also used by the collector and Grafana. |
| `GRAFANA_USER`, `GRAFANA_PASSWORD` | Grafana admin login. |
| `REGISTRY` | Registry that holds the images. Written by `startup.sh --deploy`; `run-local.sh` sets it for the run instead. |

> The `INFLUX_*` init values (user, password, org, bucket, token) only take effect the first time InfluxDB starts with an empty volume. Changing them later does not change an existing database.
>
> `.env` contains credentials. Use your own values and keep it out of version control.

## Running locally

```bash
./deploy/run-local.sh
```

This starts a local registry (on port 5000, left running afterwards), mirrors the InfluxDB and Grafana images into it, builds the collector image, and then runs `app-stack/startup.sh`. `startup.sh` removes any existing containers and starts the stack again, so running it repeatedly is safe.

Then open:

- Grafana: http://localhost:3000 (`GRAFANA_USER` / `GRAFANA_PASSWORD`)
- InfluxDB: http://localhost:8086 (`INFLUX_USER` / `INFLUX_PASSWORD`)

`docker compose` commands run by hand need `REGISTRY` set, for example `REGISTRY=localhost:5000 docker compose ps`. Plain `docker logs app-stack-collector-1` works without it.

## Deploying to a Raspberry Pi

```bash
./deploy/deploy-to-pi.sh <pi-host>
```

This script:

1. Works out the address the Pi uses to reach your machine.
2. Runs `build-to-registry.sh --platform pi` to build and mirror linux/arm64 images into the local registry.
3. Copies `grafana/`, `.env`, `docker-compose.yml` and `startup.sh` to `~/givmedagraphs` on the Pi.
4. Runs `startup.sh --deploy --registry http://<your-host>:<port>` on the Pi. That adds the registry to Docker's `insecure-registries` (restarting Docker if the config changed), records `REGISTRY` in `.env`, pulls the images, and installs and starts a `givmedagraphs.service` systemd unit so the stack starts at boot.

Your machine must stay reachable, with the registry container running, while the Pi pulls images.

## Deployment model

`docker-compose.yml` takes every image from `${REGISTRY}`, so the stack never pulls from Docker Hub at start-up. `build-to-registry.sh` fills a local registry with:

- `library/influxdb:latest`
- `grafana/grafana-oss:latest`
- `givmedagraphs/collector:latest`

It prints `REGISTRY_URL=http://<host>:5000` as its last line, which the other scripts use.

`build-to-registry.sh` options:

- `--platform <plat>`: target platform for pulled and built images, e.g. `linux/arm64`. `pi` is an alias for `linux/arm64`.
- `--advertise-host <host>`: address other machines should use, which only changes the printed `REGISTRY_URL`.

## Data storage

Data is kept in the named Docker volumes `app-stack_influxdb-data` and `app-stack_grafana-data`. Restarting or re-running the scripts keeps them. Remove them only if you want to start from scratch:

```bash
docker volume rm app-stack_influxdb-data app-stack_grafana-data
```
