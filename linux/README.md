# XMRMenuCalc for Linux

Linux port of XMRMenuCalc using Go + Fyne.

## Build

Requires Go 1.21+ and X11/Wayland development libraries:

```bash
# Debian/Ubuntu
sudo apt-get install libgl1-mesa-dev xorg-dev

# Fedora
sudo dnf install mesa-libGL-devel libXrandr-devel libXcursor-devel libXinerama-devel libXi-devel

# Arch
sudo pacman -S mesa libxrandr libxcursor libxinerama libxi
```

Then:

```bash
cd linux
./build.sh
./xmrmencalc
```

## Features

- System tray icon with live XMR price
- Popover calculator (XMR / fiat / BTC)
- 36 fiat currencies via CoinGecko
- Auto-refresh every 60 seconds

## Notes

- On first run, some desktop environments may not show the tray icon immediately. Right-click the panel/system tray area and ensure "System tray" is enabled.
- Wayland support is experimental; X11 is recommended for full system tray functionality.
