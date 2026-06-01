# Contributing to MoniScale

Thanks for your interest in contributing. MoniScale is a small, focused codebase — contributions that keep it that way are most welcome.

## What We're Looking For

Good contributions include:

- Bug fixes
- Support for additional virtual resolutions or aspect ratios
- Improved display name detection
- Accessibility improvements to the popover UI
- Better handling of edge cases (display hotplug, sleep/wake, clamshell mode)
- Test coverage for new logic

Out of scope:

- Third-party dependencies
- Features that require a login item, background daemon, or system extension
- UIKit or AppKit rewrites of the SwiftUI views
- App Store compatibility work (the private APIs preclude this)

## Getting Started

```bash
git clone https://github.com/Frostist/MoniScale.git
cd MoniScale
open MoniScale.xcodeproj
```

Build with `Cmd+R`. The app requires macOS 26+ and Xcode 26+.

## Project Structure

```
MoniScale/
├── AppDelegate.swift          # Status bar setup, popover lifecycle, display reconfiguration callback
├── DisplayManager.swift       # All display logic — mode enumeration, virtual display management
├── ScalingPopoverView.swift   # SwiftUI popover UI
├── MoniScale-Bridging-Header.h  # Private API declarations (CGVirtualDisplay, CGSDisplayMode, etc.)
MoniScaleTests/
└── MoniScaleTests.swift       # Unit tests for DisplayManager pure logic
```

The private APIs live entirely in the bridging header. `DisplayManager.swift` is the core of the app — understand that file before touching anything else.

## Making Changes

1. Fork the repo and create a branch off `main`:
   ```bash
   git checkout -b your-feature-name
   ```

2. Keep changes small and focused. One concern per PR.

3. If you're adding logic to `DisplayManager`, add a corresponding test in `MoniScaleTests.swift`. Tests that don't require a real display (pure functions like `deduplicateAndSort` and `virtualModesAbove`) are straightforward to write.

4. If you're adding a new Swift type, put it in its own file. Don't add multiple structs, classes, or enums to a single file.

5. Run the test suite before opening a PR:
   ```
   Cmd+U in Xcode
   ```

## Code Style

- Swift 5+ with modern concurrency where appropriate
- `@MainActor` on anything that touches `DisplayManager` state
- No comments unless the *why* is non-obvious — code should be self-explanatory
- No third-party frameworks
- Match the surrounding code's formatting — 4-space indentation, no trailing whitespace

## Private APIs

MoniScale relies on several undocumented macOS APIs declared in the bridging header. When working with these:

- Do not add new private API usage without a clear reason and a comment explaining what it does
- Test on the minimum supported macOS version (currently 26) as these APIs can behave differently across versions
- Document the source of any new private API signature (symbol dump, open-source reference, etc.)

## Opening a Pull Request

- Give the PR a short, descriptive title
- Explain what the change does and why in the description
- If it fixes a bug, describe how to reproduce the bug before the fix
- Keep the diff small — reviewers are volunteers

## Reporting Issues

Open a GitHub issue with:

1. macOS version
2. The external display model (if relevant)
3. Steps to reproduce
4. What you expected vs. what happened

For crashes, include the crash log from Console.app.
