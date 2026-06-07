# QWatch Companion App

Flutter companion app for the QWatch — an Arduino-based smartwatch running on the **Waveshare ESP32-S3-Touch-LCD-1.28** (240×240 capacitive touch LCD).

## Features

- **BLE connection** — scan and connect to QWatch by device name
- **Time sync** — sends current time + timezone to the watch every 5 minutes
- **Weather sync** — fetches local weather via Open-Meteo and sends to watch every 30 minutes (watch skips its own WiFi calls while connected)
- **WiFi provisioning** — send SSID and password to the watch over BLE
- **Watch face selection** — browse and set the active watch face with thumbnail previews
- **Settings** — toggle clock mode (digital / analogue), enable/disable step counter
- **Battery level** — live battery percentage via BLE notify
- **Step history** — 7-day pedometer data
- **Background mode** — Android foreground service + iOS BLE background execution keep the app syncing when not in the foreground

## Requirements

- Flutter 3.x
- Android 6.0+ (API 23) or iOS 13+
- Bluetooth LE
- Location permission (for weather — GPS used to query Open-Meteo)

## Getting Started

```bash
flutter pub get
flutter run
```

### Android

Grant **Bluetooth**, **Nearby Devices**, and **Location** permissions when prompted on first launch.

### iOS

Bluetooth and location permission prompts appear automatically. A real device is required for BLE — the simulator does not support Bluetooth.

## BLE Protocol

All communication uses a custom GATT service (`12345678-1234-1234-1234-123456780000`).

| Characteristic | UUID suffix | Direction | Format |
|---|---|---|---|
| WiFi SSID | `...0001` | Phone → Watch | UTF-8 string |
| WiFi Password | `...0002` | Phone → Watch | UTF-8 string |
| WiFi Apply | `...0003` | Phone → Watch | `0x01` to apply |
| Steps (7-day) | `...0004` | Watch → Phone | Binary (see `StepEntry`) |
| Battery % | `...0005` | Watch → Phone | 1 byte, notify |
| Settings | `...0006` | Both | JSON |
| Status | `...0007` | Watch → Phone | 2 bytes `{wifi, ntp}`, notify |
| Time | `...0008` | Phone → Watch | 8 bytes: uint32 unix_ts LE + int32 utc_offset_seconds LE |
| Weather | `...0009` | Phone → Watch | JSON `{"t":<°C>,"c":<WMO code>,"o":<utc_offset_seconds>}` |

## Project Structure

```
lib/
  ble/                  # BLE manager, UUIDs, scan/connect logic
  models/               # WatchSettings, StepEntry, face assets map
  screens/              # HomeScreen, SettingsScreen
  services/             # PhoneWeatherService (Open-Meteo), background service
assets/
  watch_faces/          # PNG thumbnails for each watch face
```

## Firmware

The watch firmware lives in the parent repository under `Qwatch/Qwatch_v5.7/`. Build and flash with Arduino IDE, board **Waveshare ESP32-S3-Touch-LCD-1.28**.
