#!/usr/bin/with-contenv bash
set -e

CONFIG_FILE="/etc/shairport-sync.conf"

echo "[INFO] Generating shairport-sync.conf"

# Werte aus Home Assistant
AIRPLAY_NAME="${airplay_name:-Home Assistant AirPlay}"
ALSA_DEVICE="${alsa_device:-hw:0,0}"
MQTT_HOST="${mqtt_host:-}"
MQTT_PORT="${mqtt_port:-1883}"
MQTT_USERNAME="${mqtt_username:-}"
MQTT_PASSWORD="${mqtt_password:-}"
MQTT_TOPIC="${mqtt_topic:-shairport-sync}"

# Datei neu erzeugen
cat > "$CONFIG_FILE" <<EOF
general =
{
  name = "${AIRPLAY_NAME}";
};

output_backend = "alsa";

alsa =
{
  output_device = "${ALSA_DEVICE}";
  mixer_control_name = "Headphone";
};
EOF

# MQTT optional
if [ -n "$MQTT_HOST" ]; then
cat >> "$CONFIG_FILE" <<EOF

mqtt =
{
  hostname = "${MQTT_HOST}";
  port = ${MQTT_PORT};
  topic = "${MQTT_TOPIC}";
EOF

  if [ -n "$MQTT_USERNAME" ]; then
    echo "  username = \"${MQTT_USERNAME}\";" >> "$CONFIG_FILE"
  fi

  if [ -n "$MQTT_PASSWORD" ]; then
    echo "  password = \"${MQTT_PASSWORD}\";" >> "$CONFIG_FILE"
  fi

cat >> "$CONFIG_FILE" <<EOF
};
EOF
fi

echo "[INFO] shairport-sync.conf created:"
echo "---------------------------------"
cat "$CONFIG_FILE"
echo "---------------------------------"
