# MoniScale

**MoniScale** is a lightweight macOS menu bar app that unlocks higher display resolutions on external monitors — no paid software, no system extensions, no bloat.

![macOS 26+](https://img.shields.io/badge/macOS-26%2B-black) ![Swift](https://img.shields.io/badge/Swift-6.0-orange) ![License](https://img.shields.io/badge/license-MIT-blue)

> **Note:** This app is in Beta and while it works, it is currently very laggy in some instances. But updates coming out soon!
---
<img width="285" height="310" alt="image" src="https://github.com/user-attachments/assets/9052cc86-91d9-4412-82b8-4252dd81a623" />

Allowing the adjustment of Monitor scaling in the macOS toolbar.

## The Problem

macOS restricts the available scaled resolutions on external monitors to whatever the display natively advertises. If you own a 1080p or 1440p external monitor, you're stuck with a handful of low-quality scaled modes — no 2K rendering, no 4K, even if your Mac is more than capable of driving it.

Tools that fix this are either expensive, bloated with features you don't need, or require persistent system extensions.

## The Solution

MoniScale lives in your menu bar and gives you a single slider per connected display. Drag it to pick any resolution — from your monitor's native modes all the way up to 4K — and MoniScale applies it instantly.

Under the hood it uses macOS's private virtual display API to create a higher-resolution virtual framebuffer, then mirrors it onto your physical display. The GPU renders at the higher resolution; macOS downsamples to your panel. The result is noticeably sharper text and UI compared to a standard low-res scaled mode.

When you quit, MoniScale cleans up all virtual displays automatically. Nothing persists, nothing lingers.

## Features

- **Menu bar app** — no Dock icon, no background services, no login items required
- **Per-monitor slider** — one control per connected external display, labelled with exact resolution
- **Native + virtual modes** — lists your monitor's real hardware modes alongside virtual above-native modes (up to 4K)
- **HiDPI detection** — marks HiDPI modes so you always know what you're selecting
- **Instant apply** — changes take effect on slider release with no confirmation dialogs
- **Auto-refresh** — detects display connect/disconnect events automatically
- **Clean teardown** — all virtual displays are removed when the app quits
- **Zero bloat** — ~300 lines of Swift, no third-party dependencies

## Supported Resolutions

Virtual modes are offered for any display whose native resolution is below 4K:

| Resolution | Label |
|---|---|
| 1920 × 1200 | 16:10 step |
| 2048 × 1152 | 2K range |
| 2560 × 1440 | 2K |
| 2560 × 1600 | 16:10 2K |
| 3008 × 1692 | 3K range |
| 3200 × 1800 | 3K HiDPI range |
| 3840 × 2160 | 4K |

## Requirements

- macOS 26 or later
- An external display (built-in displays are excluded)
- Xcode 26+ to build from source

## Installation

MoniScale is built from source. Clone the repo and open the Xcode project:

```bash
git clone https://github.com/Frostist/MoniScale.git
cd MoniScale
open MoniScale.xcodeproj
```

Build and run with `Cmd+R`. The app appears in your menu bar as a monitor icon.

> **Note:** MoniScale uses private macOS display APIs. Apple does not document these APIs and may change them in future OS releases. The app is intended for personal use and is not suitable for App Store distribution.

## How It Works

1. On launch, MoniScale enumerates all online external displays using `CGGetOnlineDisplayList`.
2. For each display it reads available hardware modes via private `CGSDisplayMode` APIs.
3. It adds virtual above-native modes using `CGVirtualDisplay` — a private API also used by apps like BetterDisplay.
4. When you select a virtual mode, MoniScale creates a virtual display at the target resolution and mirrors your physical display onto it. macOS renders the full virtual framebuffer and downsamples to your panel's native pixels.
5. When you select a native mode or quit, the virtual display is torn down cleanly.

## Privacy

MoniScale does not collect data, make network requests, or read any files outside its own process. It only calls local display APIs.

## License

MIT — see [LICENSE](LICENSE).
