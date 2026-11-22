# DIZO Watch D BLE Utilities & Custom Dial Flasher

Open-source Bluetooth Low Energy (BLE) tools and flasher for the **DIZO Watch D** (Realtek RTL8762D).

## Features

- **Time Synchronization:** Synchronize current host time or set a custom time over BLE.
- **Dial Switcher:** Switch between active watch face slots (0..4) and query dial hardware information.
- **Battery & Device Query:** Read battery percentage, charging state, and trigger vibration alerts.
- **Custom Dial Generator:** Convert custom wallpaper images (240x286 RGB565) and package them into compatible dial binary formats with updated headers and checksums.
- **Hardware-Encrypted OTA Flasher:** Direct BLE flasher implementing Realtek Silent DFU protocol with AES-256 ECB encryption and 4KB sector alignment.
- **Flutter & Web Companion Apps:** Cross-platform GUI and Web Bluetooth implementations.

---

## Directory Structure

- `python/`: Command-line tools:
  - `sync_dizo.py`: Time sync, battery query, device locator, and dial switching.
  - `process_wallpaper.py`: Image pre-processor (crops, resizes to 240x286, converts to RGB565).
  - `build_custom_dial.py`: Packages wallpaper images into dial binaries.
  - `flash_dizo_dial.py`: BLE DFU flasher with AES-256 hardware encryption.
- `flutter/`: Flutter mobile companion app with Web/Mobile Bluetooth support.
- `web/`: Lightweight Web Bluetooth interface.
- `wallpapers/`: Wallpaper assets and conversion samples.
- `watch dial templates/`: Dial binary templates and generated binaries.

---

## Prerequisites

On Linux (e.g. Debian/Ubuntu/Fedora/Arch):

```bash
sudo apt-get install -y bluez libglib2.0-dev libdbus-1-dev libssl-dev python3-pip
pip3 install -r python/requirements.txt
```

---

## Usage

### 1. Synchronize Time & Status
```bash
# Sync system time
python3 python/sync_dizo.py --sync-time

# Check battery status
python3 python/sync_dizo.py --battery

# Query watch face info
python3 python/sync_dizo.py --dial-info
```

### 2. Generate Custom Watch Face
```bash
# Process image and generate custom dial binary
python3 python/build_custom_dial.py \
  --image "wallpapers/wp3989732-smart-watch-wallpapers.jpg" \
  --position top \
  --output "watch dial templates/custom_wallpaper_dial.bin"
```

### 3. Flash Custom Watch Face
```bash
# Flash the generated dial directly over BLE
python3 python/flash_dizo_dial.py --file "watch dial templates/custom_wallpaper_dial.bin"
```

---

## CI/CD Automated Builds

A GitHub Actions workflow is provided in [`.github/workflows/build.yml`](.github/workflows/build.yml) that automatically builds:
- **Android APK:** `open-dizo-android.apk`
- **Linux AppImage:** `OpenDizo-x86_64.AppImage`

The workflow triggers on:
- Pushes and PRs touching `flutter/**`
- Manual execution via `workflow_dispatch` in the GitHub Actions tab
- Version tags (e.g. `v1.0.0`), automatically publishing release assets.

---

## Protocol Overview

- **Primary Service:** `000001ff-3c17-d293-8e48-14fe2e4da212`
  - Write: `0000ff02-0000-1000-8000-00805f9b34fb`
  - Notify: `0000ff03-0000-1000-8000-00805f9b34fb`
- **Realtek DFU Service:**
  - Control Point: `00006487-3c17-d293-8e48-14fe2e4da212`
  - Data Endpoint: `00006387-3c17-d293-8e48-14fe2e4da212`
- **Security & Framing:** AES-256 ECB encryption on DFU header and streaming sub-packets with 4KB sector alignment.
