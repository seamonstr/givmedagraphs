import asyncio
import os
import time
import logging
from givenergy_modbus.client.client import Client
from influxdb_client import InfluxDBClient, Point
from influxdb_client.client.write_api import SYNCHRONOUS

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load configuration from environment
INVERTER_IP = os.getenv('INVERTER_IP', '192.168.1.100')
INVERTER_PORT = int(os.getenv('INVERTER_PORT', '8899'))
INFLUX_URL = os.getenv('INFLUX_URL', 'http://influxdb:8086')
INFLUX_TOKEN = os.getenv('INFLUX_TOKEN', '')
INFLUX_ORG = os.getenv('INFLUX_ORG', 'solar')
INFLUX_BUCKET = os.getenv('INFLUX_BUCKET', 'solar_metrics')

# Seconds between polls. The connection to the inverter stays open between polls.
POLL_INTERVAL = float(os.getenv('POLL_INTERVAL', '5'))
# Reconnect to the inverter after this many failed polls in a row.
MAX_CONSECUTIVE_FAILURES = int(os.getenv('MAX_CONSECUTIVE_FAILURES', '3'))
# Wait this long before retrying after a failed connection attempt.
RECONNECT_DELAY = float(os.getenv('RECONNECT_DELAY', '10'))


def write_to_influx(write_api, telemetry):
    """Write telemetry data to InfluxDB using the Point API."""
    try:
        point = Point("inverter")
        for key, value in telemetry.items():
            point = point.field(key, value)
        write_api.write(INFLUX_BUCKET, INFLUX_ORG, point, write_precision='s')
        logger.info("Data written to InfluxDB: %s", telemetry)
    except Exception as e:
        logger.error(f"InfluxDB write error: {e}")


def build_telemetry(inverter):
    """Extract the fields we store from the inverter model."""
    return {
        'p_pv1': inverter.p_pv1,
        'p_pv2': inverter.p_pv2,
        'p_pv_combined': inverter.p_pv1 + inverter.p_pv2,
        'p_battery': inverter.p_battery,
        'p_grid_out': inverter.p_grid_out,
        'p_load_demand': inverter.p_load_demand,
        'battery_soc': inverter.battery_soc,
        'v_battery': inverter.v_battery,
        'i_battery': inverter.i_battery,
        'v_pv1': inverter.v_pv1,
        'v_pv2': inverter.v_pv2,
        'v_ac1': inverter.v_ac1,
        'f_ac1': inverter.f_ac1,
        't_inverter_heatsink': inverter.t_inverter_heatsink,
        'e_pv_generation_today': inverter.e_pv_generation_today,
        'e_grid_out_day': inverter.e_grid_out_day,
        'e_grid_in_day': inverter.e_grid_in_day,
    }


async def open_client():
    """Connect to the inverter and detect its topology (done once per connection)."""
    client = Client(INVERTER_IP, INVERTER_PORT)
    await client.connect()
    try:
        await client.detect()
        # Slow-changing configuration registers; read once, not every poll.
        await client.load_config()
    except Exception:
        await client.close()
        raise
    return client


async def poll_forever(write_api):
    """Poll the inverter on a fixed cadence over one long-lived connection."""
    client = None
    failures = 0
    next_poll = time.monotonic()

    while True:
        try:
            if client is None:
                client = await open_client()
                failures = 0
                next_poll = time.monotonic()

            await client.refresh()
            telemetry = build_telemetry(client.plant.inverter)
            # The Influx client is blocking, so keep it off the event loop.
            await asyncio.to_thread(write_to_influx, write_api, telemetry)
            failures = 0
        except Exception as e:
            if client is None:
                logger.error(f"💀 Could not connect to inverter: {e!r}")
                await asyncio.sleep(RECONNECT_DELAY)
                next_poll = time.monotonic()
                continue

            failures += 1
            logger.error(f"💀 Poll failed ({failures}/{MAX_CONSECUTIVE_FAILURES}): {e!r}")
            if failures >= MAX_CONSECUTIVE_FAILURES:
                logger.warning("Too many failed polls; reconnecting to the inverter")
                try:
                    await client.close()
                except Exception:
                    logger.exception("Error closing inverter connection")
                client = None
                await asyncio.sleep(RECONNECT_DELAY)
                next_poll = time.monotonic()
                continue

        # Fixed cadence: sleep until the next slot, not a fixed gap after the poll.
        next_poll += POLL_INTERVAL
        delay = next_poll - time.monotonic()
        if delay < 0:
            # Fell behind (e.g. slow poll); don't try to catch up with a burst.
            next_poll = time.monotonic()
            delay = 0
        await asyncio.sleep(delay)


def main():
    """Entry point: poll the inverter and write to InfluxDB."""
    influx_client = InfluxDBClient(
        url=INFLUX_URL,
        token=INFLUX_TOKEN,
        org=INFLUX_ORG
    )
    write_api = influx_client.write_api(write_options=SYNCHRONOUS)
    asyncio.run(poll_forever(write_api))


if __name__ == "__main__":
    main()
