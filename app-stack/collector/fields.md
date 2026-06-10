# Inverter Telemetry Field Documentation

This document contains a comprehensive breakdown of the telemetry fields from your hybrid solar inverter system. The fields have been organized into functional groups to assist with data mapping, dashboard configuration, and automation logic.

---

## 1. System Info & Hardware Configuration
These fields identify the specific hardware, model, and physical configuration of your inverter setup.

| Field Name | Description |
| :--- | :--- |
| `device_type_code` | Internal identifier code for the type of device (e.g., Hybrid, AC-coupled). |
| `model` | The specific model name/number of the inverter. |
| `module` | Hardware module identifier or series generation. |
| `num_mppt` | Number of Maximum Power Point Trackers (MPPT) available (usually 2). |
| `num_phases` | Indicates whether it is a single-phase (1) or three-phase (3) inverter. |
| `serial_number` | Unique hardware serial number of the inverter. |
| `meter_type` | The model/type of external electricity meter attached to the system. |
| `usb_device_inserted` | Boolean/flag indicating if a USB service drive is physically plugged in. |
| `enable_above_6kw_system` | Configuration flag for unlocking settings specific to larger installations (>6kW). |

---

## 2. Firmware & Communications
Controls the software brains of the operation, system time, and external communication protocols (like Modbus).

| Field Name | Description |
| :--- | :--- |
| `firmware_version` | Master firmware version of the inverter. |
| `dsp_firmware_version` | Digital Signal Processor firmware version (handles power conversion math). |
| `arm_firmware_version` | ARM processor firmware version (handles communications and logic). |
| `bms_firmware_version` | Battery Management System master firmware version. |
| `first_battery_bms_firmware_version` | Firmware version specifically of the primary/first battery pack connected. |
| `select_arm_chip` | Internal hardware identifier for the primary communication chip. |
| `modbus_address` | The slave address/ID used by the inverter on the Modbus RTU network. |
| `modbus_version` | The version protocol of the Modbus registers layout. |
| `system_time` | Current timestamp or epoch time set on the inverter clock. |
| `variable_address` | Used for debugging; the memory register currently being polled or written to. |
| `variable_value` | The raw data value inside the `variable_address`. |
| `enable_local_command_test` | Toggle allowing local network overrides or physical test triggers. |
| `cmd_bms_flash_update` | Trigger command to initiate a remote firmware flash to the battery. |
| `enable_spi` | Toggle for Serial Peripheral Interface (internal chip-to-chip comms). |

---

## 3. Real-Time Telemetry: Power, Voltage, & Current
The actual operational numbers showing what the inverter is converting, pulling, or pushing right now.

| Field Name | Description |
| :--- | :--- |
| `status` | Operational state (e.g., Waiting, Generating, Charging, Discharging, Fault). |
| `system_mode` | System operating mode profile currently active. |
| `v_pv1` / `v_pv2` | Live voltage from Solar Array String 1 and String 2. |
| `i_pv1` / `i_pv2` | Live current (amperage) from Solar Array String 1 and String 2. |
| `p_pv1` / `p_pv2` | Calculated live power (W) from Solar Array String 1 and String 2. |
| `v_p_bus` / `v_n_bus` | Positive and Negative DC Bus voltages inside the inverter. |
| `v_highbrigh_bus` | High-voltage internal bus reading. |
| `v_ac1` / `v_ac1_output` | Grid voltage reading / Voltage currently being output on the AC lines. |
| `i_ac1` | Current (amperage) flowing on the AC grid connection. |
| `f_ac1` / `f_ac1_output` | Grid frequency / Output AC frequency (usually 50Hz or 60Hz). |
| `i_grid_port` | Amperage reading specifically passing through the grid terminal port. |
| `p_grid_out` | Active power being exported to the grid (positive) or imported (negative). |
| `p_grid_out_ph1` | Export/Import power specifically on Phase 1 (for multi-phase logging). |
| `p_grid_apparent` | Apparent power (VA) drawn from/sent to the grid, combining real and reactive power. |
| `p_load_demand` | Real-time electrical demand (W) of your home/property. |
| `p_backup` | Power being drawn from the EPS/Backup critical loads port. |
| `p_combined_generation` | Sum total of all power generated across solar strings (and sometimes batteries). |
| `power_factor` | The efficiency ratio of real power to apparent power (0.00 to 1.00). |
| `pf_inverter_output_now` | Live power factor rating of the inverter's current inversion output. |
| `active_power_rate` / `reactive_power_rate` | Percentage limits or current ratios of active (W) vs reactive (VAR) power delivery. |

---

## 4. Cumulative Energy Totals (Meter Readings)
The historical counters of how many kilowatt-hours (kWh) have passed through your system over time.

| Field Name | Description |
| :--- | :--- |
| `e_pv_generation_today` | Total solar energy generated so far today. |
| `e_pv_generation_total` / `e_pv_total` | Lifetime cumulative solar energy generated. |
| `e_pv1_day` / `e_pv2_day` | Solar energy generated today specifically by String 1 and String 2. |
| `e_grid_out_day` | Total energy exported to the grid today. |
| `e_grid_in_day` | Total energy imported from the grid today. |
| `e_grid_out_total` | Lifetime cumulative energy exported to the grid. |
| `e_grid_in_total` | Lifetime cumulative energy imported from the grid. |
| `e_inverter_export_total` | Total energy output from the inverter side toward your home/grid. |
| `e_inverter_in_total` | Total energy that has passed into the inverter from AC sources. |
| `e_solar_diverter` | Energy routed specifically to a solar hot-water diverter (if installed). |
| `work_time_total_hours` | Lifetime total operational hours of the inverter. |

---

## 5. Battery Monitoring (Telemetry & Health)
Live status reporting on the state of your physical battery banks.

| Field Name | Description |
| :--- | :--- |
| `battery_soc` | State of Charge: Current battery percentage (0% - 100%). |
| `v_battery` | Live physical DC voltage of the battery bank. |
| `i_battery` | Live current (Amps) going into the battery (charging) or coming out (discharging). |
| `p_battery` | Live power (W) going into or out of the battery. |
| `charge_status` | Status code (e.g., Idle, Charging, Discharging). |
| `battery_type` | Connected battery chemistry setting (e.g., Lithium, Lead Acid). |
| `battery_capacity_ah` | Rated total amp-hour capacity of the connected battery bank. |
| `e_battery_throughput` | Total lifetime energy (kWh) that has cycled through the battery (charge + discharge). |
| `battery_calibration_stage` | Step number if the system is running a standard SoC recalibration cycle. |
| `e_discharge_year` | Energy discharged from the battery during the current calendar year. |
| `e_battery_charge_today_alt1` / `_alt2` / `_alt3` | Alternate register trackers for daily charge energy (used for verification/different apps). |
| `e_battery_discharge_today_alt1` / `_alt2` / `_alt3` | Alternate register trackers for daily discharge energy. |
| `e_battery_charge_total_alt1` / `_alt2` | Alternate register trackers for lifetime total charge. |
| `e_battery_discharge_total_alt1` / `_alt2` | Alternate register trackers for lifetime total discharge. |
| `e_ac_charge_today` | Amount of energy fed from the grid (AC) into the battery today. |

---

## 6. Battery Control & Rules (SoC Limits)
User-defined limits that tell the inverter when to stop using or charging the battery to protect its lifespan.

| Field Name | Description |
| :--- | :--- |
| `charge_soc` / `discharge_soc` | Base/Global target minimum and maximum States of Charge. |
| `battery_soc_reserve` | Hard-floor backup percentage (battery won't drop below this except during grid outages). |
| `battery_discharge_min_power_reserve` | Minimum energy reserve specifically walled off for Emergency Power Supply (EPS) usage. |
| `charge_target_soc` | Global target to stop charging when pulling energy from solar or grid. |
| `charge_soc_stop_1` / `2` | Specific SoC targets to halt charging at the end of timed Slot 1 or Slot 2. |
| `discharge_soc_stop_1` / `2` | Specific SoC floors to halt discharging at the end of timed Slot 1 or Slot 2. |
| `battery_low_voltage_protection_limit` | Hardware safety floor: Disconnect battery if physical voltage drops to this point. |
| `battery_high_voltage_protection_limit` | Hardware safety ceiling: Stop charging if physical voltage hits this limit. |
| `battery_voltage_adjust` | Calibration offset factor used to align inverter readings with physical battery readings. |

---

## 7. Charge, Discharge, & Smart Load Timers
These control the scheduled automated time windows (often used for overnight cheap-rate charging).

| Field Name | Description |
| :--- | :--- |
| `charge_slot_1` / `2` | The start/stop times configured for scheduled battery charging. |
| `charge_slot_2_x` | Extended parameters or alternate flag for charge slot 2. |
| `discharge_slot_1` / `2` | The start/stop times configured for scheduled battery discharging (force discharge). |
| `charge_slot_3` through `10` | Advanced incremental slots for complex multi-tariff charging schedules. |
| `charge_target_soc_1` through `10` | Individual target percentages assigned to each of the 10 charge slots. |
| `discharge_slot_3` through `10` | Advanced incremental slots for complex multi-tariff discharging schedules. |
| `discharge_target_soc_1` through `10` | Individual target floors assigned to each of the 10 discharge slots. |
| `smart_load_slot_1` through `10` | Timed control windows for handling an immersion heater or EV charger via a dedicated dump load port. |

---

## 8. Inverter Toggles & Feature Switches
Mainly boolean parameters (True/False or 1/0) used to change how the inverter acts dynamically.

| Field Name | Description |
| :--- | :--- |
| `enable_inverter` | Main master toggle to turn on the inversion tracking logic. |
| `enable_charge` / `enable_discharge` | Toggles to allow/disallow the battery to take or give power. |
| `enable_charge_target` | Master toggle telling the inverter to honor the custom target SoC limits. |
| `enable_ammeter` | Toggles processing data from an external current transformer clamp/meter. |
| `enable_60hz_freq_mode` | Switches system baseline calculations from standard 50Hz (UK/EU) to 60Hz (US). |
| `enable_drm_rj45_port` | Enables the Demand Response Mode port (mandated grid safety cutoff in places like Australia). |
| `enable_reversed_ct_clamp` | Digital software fix to flip the direction of an accidentally backwards physical current sensor clamp. |
| `enable_reversed_115_meter` / `418_meter` | Flips data polarity direction on specific models of digital grid meters. |
| `enable_inverter_auto_restart` | If a grid fault occurs, tells the inverter to automatically try booting back up when stable. |
| `enable_auto_judge_battery_type` | Tells the inverter to attempt autodetecting BMS parameters on initial hookup. |
| `enable_bms_read` | Allows/Disallows communication logic between the Inverter and the Battery BMS chip. |
| `enable_battery_on_pv_or_grid` | Allows battery logic to activate regardless of whether solar or AC grid is the dominant feed. |
| `enable_ups_mode` / `enable_eps` | Enables ultra-fast automatic switching to backup power terminals if grid power drops completely. |
| `enable_g100_limit_switch` | Enables UK G100 grid standard compliance rules (strict limits on unauthorized grid exporting). |
| `enable_battery_cable_impedance_alarm` | Warns if there is high resistance detected in the primary battery cables (loose terminal safety check). |
| `enable_inverter_parallel_mode` | Must be active if sharing an electrical phase load alongside a secondary twin inverter. |
| `battery_pause_mode` | Suspends all normal battery tasks (forces the battery to sit strictly idle). |
| `battery_pause_slot_1` | A timed window restricting battery charging or discharging completely. |
| `export_priority` | Rules governing what to do with excess solar power (e.g., 0 = Fill Battery First, 1 = Feed Home First). |

---

## 9. Grid Settings & Engineering Limits
Safety boundaries that protect the equipment and comply with local grid operator mandates.

| Field Name | Description |
| :--- | :--- |
| `grid_port_max_power_output` | Hard cap on the maximum continuous wattage (W) the inverter may push into the local grid. |
| `battery_power_mode` | Changes the priority tracking framework for how battery energy is calculated. |
| `battery_charge_limit` / `discharge_limit` | Max physical DC current limit (Amps) allowed into/out of the battery cells. |
| `battery_charge_limit_ac` / `discharge_limit_ac` | Max power limit (W) translated to the AC line side during charge operations. |
| `v_pv_start` | The minimum physical voltage threshold required from panels to kickstart solar inversion. |
| `start_countdown_timer` / `countdown` | Delay safety timers running before letting the system synchronize back to a live grid. |
| `restart_delay_time` | Cool-down time required after an error before trying an automated system self-start. |
| `battery_low_force_charge_time` | Safety timeout rules governing emergency grid-charging if a battery drops to critical 0%. |
| `power_factor_function_model` | Pre-programmed engineering profiles controlling active reactive-power shifts. |
| `frequency_load_limit_rate` | Variable threshold tracking when load should drop to defend the local system frequency. |
| `enable_low_voltage_fault_ride_through` | Grid code setting allowing the inverter to tolerate short local voltage sags without breaking offline. |
| `enable_frequency_derating` | Forces the inverter to automatically reduce power output if grid frequency climbs too high. |
| `threephase_balance_mode` / `threephase_abc` | Phase angle tracking configurations for ensuring balanced outputs over 3-phase setups. |
| `threephase_balance_1` / `2` / `3` | Balancing metrics or offsets across line connections 1, 2, and 3. |
| `pv_power_setting` | Global percentage cap scaling down maximum solar generation capability (e.g., for grid constraint compliance). |

---

## 10. Safety, Diagnostics, & Thermal Data
Error flags and temperatures used to prevent internal components from over-heating or malfunctioning.

| Field Name | Description |
| :--- | :--- |
| `t_inverter_heatsink` | Current temperature (°C) of the main metal cooling blocks on the inverter. |
| `t_charger` / `t_battery` | Live operating temperatures (°C) of the charging internal circuitry and battery pack. |
| `enable_buzzer` | Audible alert toggle on the physical unit chassis if a critical system fault occurs. |
| `inverter_reboot` | Soft trigger register to cycle the logic board power. |
| `start_system_auto_test` | Triggers self-test diagnostic loops (standard commission testing protocol). |
| `debug_inverter` | Software routing flag to push deeper command logs through the communication port. |
| `inverter_errors` / `fault_code` | Hexadecimal or integer registers holding active diagnostic fault codes. |
| `inverter_fault_messages` | Plain-text description translations matching the active `fault_code`. |
| `charger_warning_code` | Soft warning flags from the battery charger before they build up to a hard shutdown error. |
| `enable_rtc` | Enables or synchs the local Real-Time Clock hardware backup crystal inside the inverter. |