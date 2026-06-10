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


async def fetch_inverter_data():
    """Fetch data from the inverter."""
    client = Client(INVERTER_IP, INVERTER_PORT)
    await client.connect()
    try:
        await client.detect()
        await client.refresh_plant(full_refresh=True)
        inverter = client.plant.inverter
        logger.info(f"Inverter fields: {inverter.__fields__.keys()}")
        return inverter
    finally:
        await client.close()


def main():
    """Main loop for polling inverter and writing to InfluxDB."""
    influx_client = InfluxDBClient(
        url=INFLUX_URL,
        token=INFLUX_TOKEN,
        org=INFLUX_ORG
    )
    write_api = influx_client.write_api(write_options=SYNCHRONOUS)

    while True:
        try:
            inverter = asyncio.run(fetch_inverter_data())
            telemetry = {
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
            write_to_influx(write_api, telemetry)
        except Exception as e:
            logger.exception(f"💀 Modbus communication error: {e}")

        time.sleep(5)


if __name__ == "__main__":
    main()
