# CLAUDE.md

Context for Claude Code sessions working in this repo.

## Current status (as of 2026-07-30)

This repo was just restructured from two flat blueprint YAML files at the
repo root into the `blueprint/` / `automations/` / `helpers/` / `tools/`
layout described below, mirroring `ha_huetap_automations`. **Nothing has
been committed yet** — check `git status` first thing in a resumed session;
as of this restructuring pass it showed:

- Staged (renames): `ha_blueprint_w100_z2mqtt.yaml` →
  `blueprint/ha_blueprint_w100_z2mqtt.yaml`, and the `_thermmode_off` one
  likewise.
- Untracked: `.claude/`, `.gitignore`, `CLAUDE.md`, `automations/`,
  `blueprint/source-kipk-w100-blueprint.yaml`, `helpers/`, `tools/`.
- Modified (unstaged): `README.md`.

All content work described in this file and README.md is done — SSH
reconciliation against the live instance, automation/helper extraction,
tooling, docs. What's left is purely a git decision: review the diff, then
commit (and decide commit granularity — e.g. one commit for the file moves,
one for new content — or a single commit) once the user is ready. Don't
commit unprompted.

One open substantive question from this pass, not yet resolved: whether
`timer.bedroom_climate_controller_settimer`'s `restore: true` (vs. Office's
`restore: false`) is intentional — see README's "Known gaps" #1.

## What this repo is

A version-controlled mirror of the Aqara W100 (Zigbee2MQTT) climate-controller
blueprint stack running on a real Home Assistant Green instance (HAOS) — the
same physical instance as the `ha_huetap_automations` repo. It is **not**
deployed via `config: !include` or any HA file-sync mechanism — files here
are meant to be manually copy/pasted into HA's UI (automation/script YAML
editors) or manually re-entered (for helpers, which have no YAML-paste
import), or the blueprint files themselves manually re-uploaded via HA's
blueprint import. Treat this repo as the source of truth for *review and
planning*; the live HA instance is the source of truth for *what's actually
running* until a change here is manually applied there.

See [README.md](README.md) for the full picture of devices, structure, and
known drift/gaps. Read that first.

## Accessing the live Home Assistant instance

SSH access details (hostname/username) are **not checked into this repo** —
they live in `ha-host.env` (gitignored; copy `ha-host.env.example` to create
it) as `$HA_SSH_HOST`. Source it at the start of a session:

```
source ha-host.env
ssh "$HA_SSH_HOST"
```

All Claude Code permission rules for this repo — including the SSH/scp
pre-approvals — live in `.claude/settings.local.json`, which is gitignored
and personal to this clone (there is no git-tracked `.claude/settings.json`;
nothing permission-related is checked in). If a fresh clone gets prompted
for SSH/scp approval, that's expected: `settings.local.json` needs to be
recreated per-clone with the real `$HA_SSH_HOST` value substituted in.

`scp`'s SFTP subsystem does not work reliably over this host's SSH add-on —
prefer `ssh "$HA_SSH_HOST" 'sudo cat <path>' > localfile`
for pulling files down instead of `scp`. Confirmed 2026-07-30: `scp` failed
with `subsystem request failed on channel 0` while `ssh ... cat` worked fine
for the same files.

`ha` CLI commands (e.g. `ha core stop`, `ha core check`) do **not** work from
this SSH session — it lacks a supervisor API token, so anything requiring
Supervisor auth (Core restart, add-on control) has to be done by the user via
the HA web UI (Settings > System > Restart) or their own terminal (`ha core
stop` / `ha core start`). `sudo` on the SSH user is passwordless and works
for direct file edits under `/homeassistant` (the files there are owned by
`root:root`, and the SSH user's own uid has no write access without it).

**Entity registry edits (`.storage/core.entity_registry` and similar) require
Core to be fully STOPPED, not just restarted** — same lesson learned in the
huetap repo (see that repo's CLAUDE.md for the full incident writeup). The
reliable sequence: ask the user to run `ha core stop` themselves and confirm
it's done, make the edit (always `sudo cp` a timestamped backup first), then
ask them to run `ha core start`. Editing `automations.yaml` itself (not the
registry) is safe with Core running.

Key facts about the live layout (full detail in
`ha_huetap_automations/home-assistant-green-filesystem-layout.md`, not
duplicated here since it's the same instance):

- HA config root: `/homeassistant` (equivalent to `/config` in HA docs)
- Automations: single flat file, `/homeassistant/automations.yaml`, keyed by
  `- id: '<timestamp-ish-id>'` / `alias:` pairs — **not** one-file-per-automation
  on the live instance. This repo splits them out into individual files by
  design, unlike the live layout.
- Blueprints: `/homeassistant/blueprints/automation/<author>/<name>.yaml` —
  this stack's blueprints live under `mexigabacho/` (self-authored/forked).
  A third-party alternative, `KipK/w100-blueprint.yaml`, also exists on the
  live instance but is **not used by any automation** — kept in this repo
  under `blueprint/source-kipk-w100-blueprint.yaml` for reference only.
- Helpers (`input_select`, `timer`, etc.) live in `/homeassistant/.storage/<domain>`
  as JSON, not YAML. Read them with Python's `json` module over SSH, e.g.:
  ```bash
  ssh "$HA_SSH_HOST" '
  python3 -c "
  import json
  d = json.load(open(\"/homeassistant/.storage/input_select\"))
  for item in d[\"data\"][\"items\"]:
      print(item)
  "'
  ```
- Entity registry (for cross-referencing entity_id -> device/platform):
  `/homeassistant/.storage/core.entity_registry`

## Reconciling blueprint files against the live instance

**Confirmed 2026-07-30**: pulling the live copies of both `mexigabacho/`
blueprints and diffing (structurally, ignoring YAML formatting/key-ordering)
against this repo's `blueprint/` copies showed **no logic differences** —
every diff was HA's own re-serialization on import (selector schema defaults
getting filled in, e.g. `domain: climate` → `domain: [climate]`,
`boolean: null` → `boolean: {}`, number selectors gaining an explicit
`mode: slider`, and an auto-added `source_url` pointing at this repo's own
GitHub). No triggers, conditions, or actions differed. **Don't assume this
holds forever** — re-diff (same method: parse both with a `!input`-aware
YAML loader, compare the resulting dicts, not raw text) before trusting this
repo's copy if either blueprint is edited on either side.

## Live devices on this stack

Two W100 devices are deployed, both using
`mexigabacho/ha_blueprint_w100_z2mqtt_thermmode_off.yaml` (the mode-cycling
button controller) and both syncing HVAC-set-mode changes against the same
main thermostat, `climate.living_room` (a Nest thermostat entity — confirmed
via `core.entity_registry`, platform `nest`). The plain bidirectional-sync
blueprint (`ha_blueprint_w100_z2mqtt.yaml`) is **not referenced by any live
automation** — kept in this repo as a future option, not currently in use.

| Location | MQTT topic | Automation | W100 entity |
|---|---|---|---|
| Office | `zigbee2mqtt/Office-Climate-Controller` | `Office-Climate-Controller-Buttons` | `climate.office_climate_controller` |
| Bedroom | `zigbee2mqtt/Bedroom-Climate-Controller` | `Bedroom-Climate-Controller-Buttons` | `climate.bedroom_climate_controller` |

Both devices' `ceiling_fan` mode controls a room fan (`fan.office_fan` /
`fan.bedroom_fan_2`) via single/double +/- press, and both have
`double_center_reset: false` with `double_center_action: fan.toggle` — i.e.
double-tapping center toggles the fan rather than resetting to default mode.
Neither device's `custom` mode has any actions assigned yet (both
`custom_*` blueprint inputs are unset/empty on the live instance).

## Working conventions for this repo

- **Every YAML file under `automations/` should be directly pasteable** into
  HA's automation YAML-mode editor — no wrapper keys, no `- id:` array syntax
  (that's only valid in the flat `automations.yaml` file on the live instance
  itself).
- **Helper files under `helpers/`** are reference/documentation, not
  paste-ready — HA has no YAML import for helpers. Keep the inline comment
  at the top of each explaining this and pointing to the UI path.
- **Blueprint files under `blueprint/`** are close to paste-ready (HA's
  blueprint import accepts YAML directly), but expect HA to re-serialize
  selector defaults on import/save — see "Reconciling blueprint files" above.
  Don't treat a live re-diff showing formatting noise as a reason to "fix"
  this repo's copy to match; the local copy (cleaner, hand-authored
  formatting with section-header comments) is the one to keep editing.
- When pulling anything fresh from the live instance, prefer re-fetching
  over trusting this repo's copies if there's any doubt they've drifted —
  the live instance is ground truth for "what's actually running."
- This repo was restructured 2026-07-30 to mirror `ha_huetap_automations`'s
  layout (`blueprint/`, `automations/`, `helpers/`, `tools/`, this file). Prior
  to that, it held two flat blueprint YAML files at the repo root with no
  tooling or live-instance integration.
