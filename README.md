# ha_blueprint_wd100_z2mqtt
Blueprint for Home Assistant that helps integrate the WD100 (via zigbee2mqtt).  

Can syncronize display/controls with home assistant thermostat (in thermostat mode) and/or control the button presses on the device.

This requires MQTT as it utilizes the device's topic to get specific button presses.  It utilizes home assistant's native thermostat entities for thermostat syncronization.

Key features:

- MQTT trigger for button actions.
- Sync direction input — bidirectional, main as master, or W100 as master
- Fan mode translation — W100 auto/low/medium/high ↔ on/off
- Fixed fallback mode — no longer hardcoded to heat, now picks first supported mode
- External data via direct MQTT publish — uses confirmed working topic/payload format
- Button actions — all 6 press types with single press gated on thermostat mode state

Key points:
- If you have the device in thermostat mode, then you likely do not want to use single button press events as those will be handled natively by the device (to switch thermostat modes [cool, heat, off]. fan modes [auto,low,medium,high], and thermostat temp settings).  In short, you likely do notwant pressing '+' or '-' buttons (top and bottom buttons) once to perform a home assistant action at the same time that the device will be performing thermostat actions.
- If you do not have the device in thermostat mode, then all button press options will be allowed (single press, double press).


