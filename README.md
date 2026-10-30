# ThinkVision Monitor Switch & USB KVM Auto-Sync

Automated monitor input switching and USB KVM synchronization for macOS (Apple Silicon / Intel) and the **Lenovo ThinkVision P32p-20** (or similar monitors with built-in USB KVM switches).

---

## Overview

When using a monitor with a built-in KVM switch connected to both a **Mac** (via HDMI/DisplayPort + USB upstream) and a **Windows Laptop** (via USB-C upstream + display), switching the KVM or switching inputs manually requires multiple button presses on the monitor.

This project solves this with two complementary tools:

1. **`monitor_usb_sync` (Swift Daemon)**:
   - Runs as a lightweight macOS `LaunchAgent` in the background.
   - Listens to kernel `IOKit` USB device notifications for the monitor's internal Realtek USB hub (`0x0bda:0x5411`).
   - When the KVM switches away from the Mac to the laptop, the daemon detects the USB hub disconnect and automatically commands the monitor via DDC/CI to switch its video input to **USB-C (16)**.
   - When the KVM switches back to the Mac, the daemon detects the USB hub reconnect and automatically switches the video input back to **HDMI (17)**.

2. **`switch-monitor` (CLI Utility)**:
   - Fast command-line script to toggle or set inputs directly from Terminal or keyboard shortcuts.
   - Supports: `switch-monitor toggle`, `switch-monitor hdmi`, `switch-monitor usbc`, `switch-monitor dp`, `switch-monitor status`.

---

## Hardware Configuration

- **Monitor**: Lenovo ThinkVision P32p-20 (3840x2160 @ 60Hz)
- **Host 1 (Mac Mini M4)**: HDMI (`input: 17`) + USB-B Upstream
- **Host 2 (Windows Laptop)**: USB-C (`input: 16`) carrying DisplayPort Alt-Mode + USB Upstream
- **USB Hub Hardware ID**: `Vendor: 0x0bda` (Realtek), `Product: 0x5411`

---

## Prerequisites

- macOS 12+ (Apple Silicon or Intel)
- Xcode Command Line Tools (`xcode-select --install`)
- `m1ddc` (DDC/CI control tool for Apple Silicon):
  ```bash
  brew install m1ddc
  ```

---

## Quick Start

### 1. Build & Install Daemon
Clone and run `make install`:

```bash
make install
```

This will:
1. Compile `src/monitor_usb_sync.swift` into a native binary.
2. Install the binary and CLI script to `~/scripts` and symlink to `~/.local/bin/switch-monitor`.
3. Install and load the macOS LaunchAgent (`~/Library/LaunchAgents/com.hbl.monitor-usb-sync.plist`).

### 2. Manual CLI Usage

```bash
# Toggle between Mac (HDMI 17) and Windows (USB-C 16)
switch-monitor

# Switch explicitly
switch-monitor hdmi
switch-monitor usbc
switch-monitor dp

# View current input
switch-monitor status
```

### 3. Check Service Status & Logs

```bash
# Check if background daemon is running
make status

# Stream daemon activity logs
make logs
# Or: tail -f ~/monitor_usb_sync.log
```

---

## Customization

If your monitor uses different input codes or a different USB hub ID:

1. Discover your monitor's current input code:
   ```bash
   m1ddc get input
   ```
2. Find your monitor's internal USB Hub Vendor and Product ID:
   ```bash
   system_profiler SPUSBDataType
   ```
3. Update `src/monitor_usb_sync.swift` (`targetVendor`, `targetProduct`, `macInput`, `windowsInput`) and re-run:
   ```bash
   make install
   ```

---

## License

MIT
