# OMORI — macOS Intel Patch

A compatibility patch for the Steam version of **OMORI** on Intel-based Macs (x86_64), fixing crashes and launch failures caused by outdated runtime components.

> **⚠️ Intel only.** This patch does not support Apple Silicon (M1/M2/M3).

## What it fixes

- Black screen / "Steam has not been detected" on launch
- Game crash when selecting **New Game** or **Continue**
- Random crashes during gameplay (GPU/Canvas rendering)
- Save file corruption on modern Node.js

## Requirements

- macOS with an **Intel x86_64** processor
- OMORI installed via **Steam**
- An active internet connection (the script downloads required components)

## Installation

Open Terminal and run:

```bash
curl -fsSL https://raw.githubusercontent.com/leandro754/omori-patch-mac-intel/main/install.sh | bash
```

Then launch OMORI normally through Steam.

> If you verify game files via Steam after patching, you will need to re-run the script.

## Manual Installation

```bash
git clone https://github.com/leandro754/omori-patch-mac-intel.git
cd omori-patch-mac-intel
chmod +x install.sh
./install.sh
```

To specify a custom OMORI install path:

```bash
OMORI_DIR="/path/to/OMORI" ./install.sh
```

## Components

| Component | Version |
|---|---|
| NW.js | 0.98.0 (x64) |
| Greenworks | 0.20.0 |
| Steamworks SDK | 1.62 |

## Disclaimer

This repository does not include or distribute any game files. A legitimate copy of OMORI on Steam is required.
