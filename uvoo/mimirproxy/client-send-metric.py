import os
import time
import requests
import snappy
import warnings

# Suppress the InsecureRequestWarning when verify=False is used
warnings.filterwarnings("ignore", message="Unverified HTTPS request")

# Assuming these are available from previous setup or environment variables
from remote_pb2 import WriteRequest
from types_pb2 import TimeSeries
from gogoproto.gogo_pb2 import *

MIMIR_URL = os.getenv('MIMIR_URL')
AUTH = (os.getenv('MIMIR_USER'), os.getenv('MIMIR_PASS'))
TLS_VERIFY = False
        # "X-Scope-OrgID": "org1"

def create_remote_write_payload():
    """
    Constructs a Remote Write Protobuf payload for Mimir.
    """
    remote_write = WriteRequest()
    series = remote_write.timeseries.add()
    series.labels.add(name="__name__", value="example_metric")
    series.labels.add(name="job", value="example")
    ts = int(time.time() * 1000)
    sample = series.samples.add(value=42, timestamp=ts)
    return remote_write.SerializeToString()

def send_protobuf():
    """
    Compresses and sends the Protobuf payload to Mimir.
    """
    payload = create_remote_write_payload()
    compressed_payload = snappy.compress(payload)

    headers = {
        "Content-Type": "application/x-protobuf",
        "Content-Encoding": "snappy",
    }

    print(f"Sending data to {MIMIR_URL} with TLS verification skipped...")
    # Add verify=False here to skip TLS verification
    response = requests.post(MIMIR_URL, data=compressed_payload, headers=headers, auth=AUTH, verify=TLS_VERIFY)

    print(f"Protobuf Response: {response.status_code} - {response.text}")

# Ensure environment variables are set before running
# Example:
# export MIMIR_URL="https://your-mimir-endpoint:8080/api/v1/push"
# export MIMIR_USER="your_username"
# export MIMIR_PASS="your_password"

if __name__ == "__main__":
    if not MIMIR_URL:
        print("Error: MIMIR_URL environment variable is not set.")
    else:
        send_protobuf()
