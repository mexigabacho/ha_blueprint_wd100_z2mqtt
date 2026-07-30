# ha_blueprint_wd100_z2mqtt

Version-controlled Home Assistant blueprint stack for the Aqara W100 climate
sensor/controller (via Zigbee2MQTT), plus the automations and helpers that
use it on my Home Assistant Green (HAOS) instance — the same physical
instance as my [`ha_huetap_automations`](../ha_huetap_automations) repo. This
repo mirrors what's live on the HA instance so changes can be reviewed/diffed
here before being pasted/uploaded back into HA's UI.

## Background

The W100 is an Aqara climate sensor/controller with a small display and
physical +/-/center buttons, paired over Zigbee2MQTT. It doesn't natively
sync with a "real" HVAC system, so this stack provides two blueprints to
bridge that gap:

- **`ha_blueprint_w100_z2mqtt_thermmode_off.yaml`** ("Aqara W100 Button
  Controller (Thermostat Mode OFF)") — **the one actually in use.** Turns the
  W100's buttons into a mode-cycling remote: center button cycles through
  three modes (`ceiling_fan`, `hvac_set`, `custom`), +/- do different things
  depending on the active mode, and an inactivity timer auto-returns to a
  default mode. In `hvac_set` mode, +/- directly adjust the main thermostat's
  setpoint and the W100's own display flashes to indicate it's in
  setpoint-adjustment mode.
- **`ha_blueprint_w100_z2mqtt.yaml`** ("Aqara W100 Thermostat & Button
  Controller") — a bidirectional (or master/follower) HVAC sync blueprint
  between the W100's own climate entity and a main thermostat, plus optional
  external temperature/humidity publishing to the W100's display. **Not
  currently used by any live automation** — kept as a documented, ready
  option if full thermostat-mode sync is ever wanted instead of (or in
  addition to) the button-controller approach.

A third blueprint, `KipK/w100-blueprint.yaml` ("Aqara W100 Thermostat
Synchronization"), is installed on the live instance but unused by any
automation — a third-party alternative covering similar ground to
`ha_blueprint_w100_z2mqtt.yaml`. Kept here as
`blueprint/source-kipk-w100-blueprint.yaml` for reference/diffing only.

## Devices

Two W100 devices are deployed, both on the thermmode-off button-controller
blueprint, both syncing setpoint changes (in `hvac_set` mode) against the
same main thermostat — `climate.living_room`, a Nest thermostat.

| Location | MQTT topic | Automation | Blueprint used |
|---|---|---|---|
| Office | `zigbee2mqtt/Office-Climate-Controller` | `Office-Climate-Controller-Buttons` | thermmode_off |
| Bedroom | `zigbee2mqtt/Bedroom-Climate-Controller` | `Bedroom-Climate-Controller-Buttons` | thermmode_off |

Per-device button/mode layout (both devices share this shape):

- **Center button** — single press cycles `ceiling_fan` → `hvac_set` →
  `custom` → back to `ceiling_fan`. Double press does **not** reset to
  default mode on either device (`double_center_reset: false`) — instead it
  fires `double_center_action`, which both devices wire to `fan.toggle`
  against their room fan.
- **`ceiling_fan` mode** — +/- single press = increase/decrease fan speed;
  +/- double press = fan on (full)/off. Office targets `fan.office_fan`;
  Bedroom targets `fan.bedroom_fan_2`.
- **`hvac_set` mode** — +/- single press adjusts `climate.living_room`'s
  setpoint by 1° (blueprint default); double press adjusts by 3° (both
  devices override `hvac_setpoint_step_double: 3`). The W100's bottom
  display flashes between 0 and 88 while active — Bedroom sets
  `hvac_set_flash: true` explicitly; Office relies on the blueprint's own
  default (also `true`), so both behave the same but from different
  sources in their `automations/*.yaml` files.
- **`custom` mode** — no actions assigned on either device yet (all
  `custom_*` blueprint inputs are unset). Available if a third distinct
  button behavior is ever wanted.

Both devices also publish `climate.living_room`'s own paired sensors,
`sensor.living_room_temperature`/`sensor.living_room_humidity`, to their W100
display in non-`hvac_set` modes (`external_temperature_sensor`/
`external_humidity_sensor` blueprint inputs).

## Directory structure

```
blueprint/    The blueprint(s): installed/local copies, plus a third-party
              reference blueprint not currently in use.
automations/  One YAML file per automation, pasteable into HA's automation
              editor (YAML mode).
helpers/      One YAML file per helper (input_select / timer), documenting
              the config since HA helpers are UI/`.storage`-managed and have
              no YAML-paste import.
tools/        Local debugging/maintenance scripts (not HA entities) — e.g.
              a live MQTT traffic watcher for debugging device actions.
```

### `blueprint/`
- `ha_blueprint_w100_z2mqtt_thermmode_off.yaml` — the button-controller
  blueprint, **in live use** by both devices. Installed live at
  `/homeassistant/blueprints/automation/mexigabacho/ha_blueprint_w100_z2mqtt_thermmode_off.yaml`.
- `ha_blueprint_w100_z2mqtt.yaml` — the bidirectional sync blueprint,
  **not currently used** by any automation. Installed live at
  `/homeassistant/blueprints/automation/mexigabacho/ha_blueprint_w100_z2mqtt.yaml`
  for future use if wanted.
- `source-kipk-w100-blueprint.yaml` — third-party reference blueprint
  (`KipK/w100-blueprint.yaml` on the live instance), unused by any
  automation. Kept for comparison against the self-authored sync blueprint
  above, similar to how `ha_huetap_automations` keeps the original
  unmodified community blueprint for diffing against its own fork.

Confirmed 2026-07-30: diffing the live copies of both `mexigabacho/`
blueprints against these local files (structurally, not as raw text) showed
zero logic differences — only HA's own selector-schema normalization on
import. See [CLAUDE.md](CLAUDE.md) for the reconciliation method if this
needs re-checking later.

### `automations/`
- `office-climate-controller.yaml`, `bedroom-climate-controller.yaml` — the
  two live `use_blueprint` automations, one per W100 device, both on the
  thermmode_off blueprint.

### `helpers/`
One YAML per helper (2 `input_select`, 2 `timer`), formatted as the config
fields you'd enter in HA's **Settings > Devices & Services > Helpers >
Create Helper** UI. HA has no built-in "paste YAML to create a helper" flow —
these files exist for reference/version-control and manual re-entry, not
literal paste-in.

**Note**: both timers use `restore: false` (confirmed/aligned 2026-07-30 —
see "Known gaps" #1, resolved).

## Known gaps / drift

Discovered while restructuring this repo and reconciling against the live
instance on 2026-07-30.

1. ~~`timer.bedroom_climate_controller_settimer` used `restore: true` while
   Office's equivalent used `restore: false`.~~ **Resolved 2026-07-30** —
   normalized to `restore: false` on both, matching Office's config. See
   "Bedroom W100 buttons unresponsive" incident below for the session this
   came up in.
2. **`custom` mode has no actions assigned on either device.** Not a bug —
   just an unused capability of the blueprint. Worth knowing if a third
   distinct button behavior is ever wanted without adding a fourth mode.
3. **The bidirectional sync blueprint (`ha_blueprint_w100_z2mqtt.yaml`) is
   installed live but unused.** Not a bug — kept intentionally as a
   documented option. If it's ever wired up, update this README's device
   table and the "Background" section above.

## Incident: Bedroom W100 buttons unresponsive (2026-07-30)

The Bedroom W100's buttons stopped producing any effect, while the
otherwise-identical Office W100 kept working fine on the same blueprint.
Troubleshooting steps and findings, in case this recurs:

- Both devices had `thermostat_mode: OFF` (the blueprint's hard requirement)
  — that wasn't the cause.
- Bedroom and Office turned out to be running **different Z-stack firmware
  builds** of the same `TH-S04D` model (`date_code` `20260518` on Bedroom vs.
  `20260128` on Office). Aligning the two devices' other Zigbee settings
  (`auto_hide_middle_line`, `temp_report_mode`, `temp_period`,
  `temp_threshold`, `humi_period`, `high_humidity`, `low_humidity`) to match
  did **not** fix it.
- Live-watching MQTT (`./tools/mqtt-watch.sh "zigbee2mqtt/Bedroom-Climate-Controller"`)
  while pressing buttons showed **zero traffic at all** — not even a failed
  delivery or a routine state report during the press. The device's
  `bridge/health` message counter was still climbing over time (so it wasn't
  fully offline), meaning routine sensor reports worked but button `action`
  events specifically weren't reaching Z2M — and silently, with no error
  logged.
- This matches a pattern seen repeatedly in upstream Zigbee2MQTT issues for
  Aqara devices generally: `action` reporting can silently break after a
  firmware version change, when the paired device and the installed
  zigbee-herdsman-converters version disagree on frame format, with no
  logged error (see e.g. Koenkk/zigbee2mqtt#28521 for a related silent-failure
  bug on this same W100/TH-S04D model, and #25450/#25526/#25640 for the
  broader Aqara pattern).
- **Fix**: resetting the Bedroom W100 and letting it reconnect/re-pair with
  Zigbee2MQTT resolved it — likely cleared a stale Zigbee
  binding/route/interview cache left over from before the firmware update.
  Verified after the fix by watching MQTT while pressing all six actions
  (`single_plus`, `single_minus`, `double_plus`, `double_minus`,
  `single_center`, `double_center`) and confirming each one came through.

**If a W100's buttons stop working again**: first confirm it's specifically
button `action` events missing (not general connectivity — check
`bridge/health` message counts and thermostat_mode first). If action events
are silently absent, try resetting/re-pairing the device before assuming a
config or blueprint problem — this has already resolved the issue once.

## Working with this repo

See [CLAUDE.md](CLAUDE.md) for how Claude Code should approach this repo in
future sessions (SSH access, file layout on the HA host, how to push changes
back, and how blueprint reconciliation was verified).
