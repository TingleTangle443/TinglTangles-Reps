#!/bin/sh

CONFIG="/data/options.json"
CONF_FILE="/etc/shairport-sync.conf"

echo "Generating shairport-sync.conf from Home Assistant options..."

AIRPLAY_NAME=$(jq -r '.airplay_name' "$CONFIG")
ALSA_DEVICE=$(jq -r '.alsa_device' "$CONFIG")
LATENCY=$(jq -r '.latency' "$CONFIG")
INTERPOLATION=$(jq -r '.interpolation' "$CONFIG")

MQTT_HOST=$(jq -r '.mqtt_host' "$CONFIG")
MQTT_PORT=$(jq -r '.mqtt_port' "$CONFIG")
MQTT_USER=$(jq -r '.mqtt_username' "$CONFIG")
MQTT_PASSWORD=$(jq -r '.mqtt_password' "$CONFIG")
MQTT_TOPIC=$(jq -r '.mqtt_topic' "$CONFIG")

cat > "$CONF_FILE" <<EOF
general =
{
  name = "$AIRPLAY_NAME";
  interpolation = "$INTERPOLATION";
  output_backend_latency_offset = $LATENCY;
};

audio_backend = "alsa";

alsa =
{
  output_device = "$ALSA_DEVICE";
};

mqtt =
{
  enabled = "yes";
  hostname = "$MQTT_HOST";
  port = $MQTT_PORT;
  username = "$MQTT_USER";
  password = "$MQTT_PASSWORD";
  topic = "$MQTT_TOPIC";
};
EOF
