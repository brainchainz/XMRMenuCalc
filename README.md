# XMRMenuCalc

A minimal macOS menu bar app that shows live Monero (XMR) price and opens a quick-conversion calculator. No dock icon, no clutter.

## What it does

- Lives in your status bar with the Monero logo
- Shows live XMR price in USD (via CoinGecko)
- Click the icon → popover calculator for XMR / USD / BTC conversions
- Supports 36 fiat currencies
- macOS and Linux builds available

## Screenshot

![XMRMenuCalc UI](XMRMenuCalc-UI-screenshot.png)

## Install

### macOS

#### Option 1: Download DMG (easiest)

1. Download `XMRMenuCalc.dmg` from [Releases](../../releases)
2. Open the DMG, drag `XMRMenuCalc` to **Applications**
3. Launch from Applications (or Spotlight: `Cmd+Space`, type `xmr`)
4. Approve in **System Settings → Privacy & Security** if Gatekeeper complains

#### Option 2: Build from source

Requires macOS 13+, Xcode command line tools, and Swift 5.9+.

```bash
git clone <repo-url>
cd XMRMenuCalc
./build.sh
open build/XMRMenuCalc.app
```

**Or with Swift Package Manager:**

```bash
swift build
```

**Or open in Xcode:**

```bash
open XMRMenuCalc.xcodeproj
```

### Linux

#### Option 1: Download binary

1. Download `xmrmencalc-linux-amd64.tar.gz` from [Releases](../../releases)
2. Extract: `tar xzf xmrmencalc-linux-amd64.tar.gz`
3. Run: `./xmrmencalc-linux/xmrmencalc`

#### Option 2: Build from source

Requires Go 1.21+ and X11/Wayland dev libraries:

```bash
# Debian/Ubuntu
sudo apt-get install libgl1-mesa-dev xorg-dev

# Fedora
sudo dnf install mesa-libGL-devel libXrandr-devel libXcursor-devel libXinerama-devel libXi-devel

# Then build
cd linux
./build.sh
./xmrmencalc
```

## First launch

Since the app is ad-hoc signed (not notarized), macOS will block it on first open. Right-click the app in Applications and choose **Open**, or go to **System Settings → Privacy & Security** and click **Open Anyway**.

## Uninstall

Drag `XMRMenuCalc.app` from Applications to Trash. No config files are written.

## Support

If you find XMRMenuCalc useful, a suggested donation is **$1 of XMR** to support Monero software development:

- **Kuno fundraiser:** https://kuno.anne.media/fundraiser/ufmp/
- **XMR address:** `489mHXbSehCF5oraCQvmRYSe9mkxyqZ6XJBS8A4af6qzbKBx3b26bLSRUVso9R6PTSgEX7RggVPc5hxcZnAaRKCT7iekvDX`

## License

MIT
