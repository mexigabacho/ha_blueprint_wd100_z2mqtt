#!/usr/bin/env bash
# Live-watch MQTT traffic on the HA instance's Mosquitto broker, for
# debugging Zigbee2MQTT device actions (button presses, dial rotation,
# hvac_set mode, etc.) in real time.
#
# Never stores the broker password anywhere -- reads it fresh from
# HA's own .storage/core.config_entries on each run, over SSH.
#
# Usage:
#   ./tools/mqtt-watch.sh                                          # watch all zigbee2mqtt/# traffic
#   ./tools/mqtt-watch.sh "zigbee2mqtt/Office-Climate-Controller"
#   ./tools/mqtt-watch.sh "zigbee2mqtt/Office-Climate-Controller" 30   # 30 second timeout instead of default 60
#
# Requires: SSH access to your HA instance, configured via $HA_SSH_HOST
# (e.g. `source ha-host.env` -- see CLAUDE.md and ha-host.env.example).

set -euo pipefail

if [ -z "${HA_SSH_HOST:-}" ]; then
  echo "HA_SSH_HOST is not set. Copy ha-host.env.example to ha-host.env," >&2
  echo "fill in your SSH target, and run: source ha-host.env" >&2
  exit 1
fi
HA_HOST="$HA_SSH_HOST"
TOPIC="${1:-zigbee2mqtt/#}"
DURATION="${2:-60}"

echo "Watching topic '${TOPIC}' for ${DURATION}s (Ctrl+C to stop early)..."
echo "Press/hold/rotate the device now."
echo "---"

ssh "$HA_HOST" "
PASSWORD=\$(python3 -c \"
import json
d = json.load(open('/homeassistant/.storage/core.config_entries'))
for e in d['data']['entries']:
    if e.get('domain') == 'mqtt':
        print(e['data']['password'])
\")
timeout ${DURATION} mosquitto_sub -h core-mosquitto -p 1883 -u homeassistant -P \"\$PASSWORD\" -t '${TOPIC}' -v
"
