import asyncio
import os
import logging
from givenergy_modbus.client import GivEnergyClient
from influxdb_client import InfluxDBClient
from influxdb_client.client.write_api import ASYNCHRONOUS

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load configuration from environment
INVERTER_IP = os.getenv('INVERTER_IP', '192.168.1.100')
INFLUX_URL = os.getenv('INFLUX_URL', 'http://influxdb:8086')
INFLUX_TOKEN = os.getenv('INFLUX_TOKEN', '')
INFLUX_ORG = os.getenv('INFLUX_ORG', 'solar')
INFLUX_BUCKET = os.getenv('INFLUX_BUCKET', 'solar_metrics')

# Field validation thresholds
FIELD_THRESHOLDS = {
    'p_pv_start': 0,
    'p_battery': 0,
    'p_grid_out': 0,
    'soc': 0
}

async def write_to_influx(write_api, data):
    """Write validated telemetry data to InfluxDB."""
    try:
        await write_api.write(
            INFLUX_BUCKET,
            INFLUX_ORG,
            data,
            write_precision='s'
        )
        logger.info("Data written to InfluxDB")
    except Exception as e:
        logger.error(f"InfluxDB write error: {e}")

def validate_telemetry(data):
    """Discard telemetry spikes with sudden 0 values."""
    for field, threshold in FIELD_THRESHOLDS.items():
        if field in data and data[field] <= threshold:
            logger.warning(f"Invalid {field} value: {data[field]}")
            return False
    return True

def fetch_inverter_data():
    """Synchronously fetch data from the inverter."""
    client = GivEnergyClient(host=INVERTER_IP)
    client.refresh_plant(full_refresh=True)
    inverter = client.plant.inverter
    return {
        'p_pv_start': inverter.p_pv1 + inverter.p_pv2,
        'p_battery': inverter.p_battery,
        'p_grid_out': inverter.p_grid_out,
        'soc': inverter.battery_percent
    }

async def main():
    """Main async loop for polling inverter and writing to InfluxDB."""
    # Setup InfluxDB client
    influx_client = InfluxDBClient(
        url=INFLUX_URL,
        token=INFLUX_TOKEN,
        org=INFLUX_ORG
    )
    write_api = influx_client.write_api(write_options=ASYNCHRONOUS)

    loop = asyncio.get_event_loop()

    while True:
        try:
            # Run synchronous inverter fetch in a thread executor to avoid blocking
            telemetry = await loop.run_in_executor(None, fetch_inverter_data)

            if validate_telemetry(telemetry):
                influx_data = f'inverter p_pv_start={telemetry["p_pv_start"]},p_battery={telemetry["p_battery"]},p_grid_out={telemetry["p_grid_out"]},soc={telemetry["soc"]}'
                await write_to_influx(write_api, influx_data)
                logger.info("Wrote data to influx: %s", influx_data)
            else:
                logger.warning("Discarded invalid telemetry data")
        except Exception as e:
            logger.exception(f"💀 Modbus communication error: {e}")

        await asyncio.sleep(5)

if __name__ == "__main__":
    asyncio.run(main())
