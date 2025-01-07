#!/bin/bash

# Kasa Collector Configuration
INFLUXDB_BUCKET="kasa"
INFLUXDB_USERNAME="sammy"
INFLUXDB_PASSWORD="sammy_admin"
INFLUXDB_URL="http://cygnus:8086"
TPLINK_USERNAME="your_tplink_username"    # Replace with your TP-Link username
TPLINK_PASSWORD="your_tplink_password"    # Replace with your TP-Link password
DEVICE_HOSTS="192.168.2.102"
TZ="America/New_York"

# Run Kasa Collector Docker container
docker run -d \
   --name=kasa-collector \
   -e KASA_COLLECTOR_INFLUXDB_BUCKET=$INFLUXDB_BUCKET \
   -e KASA_COLLECTOR_INFLUXDB_USERNAME=$INFLUXDB_USERNAME \
   -e KASA_COLLECTOR_INFLUXDB_PASSWORD=$INFLUXDB_PASSWORD \
   -e KASA_COLLECTOR_INFLUXDB_URL=$INFLUXDB_URL \
   -e KASA_COLLECTOR_TPLINK_USERNAME=$TPLINK_USERNAME \
   -e KASA_COLLECTOR_TPLINK_PASSWORD=$TPLINK_PASSWORD \
   -e KASA_COLLECTOR_DEVICE_HOSTS=$DEVICE_HOSTS \
   -e KASA_COLLECTOR_ENABLE_AUTO_DISCOVERY=false \
   -e TZ=$TZ \
   --restart always \
   --network host \
   lux4rd0/kasa-collector:latest
