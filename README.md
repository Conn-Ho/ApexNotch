# ⚡ ApexNotch

> A native Swift macOS developer command center that lives in your menu bar — with animated notch glow effects that reflect your system state.

![macOS](https://img.shields.io/badge/macOS-14.0+-black?style=flat-square&logo=apple)
![Swift](https://img.shields.io/badge/Swift-6.0-orange?style=flat-square&logo=swift)
![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)
![Version](https://img.shields.io/badge/version-0.1.0-green?style=flat-square)

## What is ApexNotch?

ApexNotch turns your MacBook Pro notch into a live status indicator. A pulsing glow emanates from the notch — green when everything is running, red when a process crashes, amber when an agent stalls. Open the menu bar popover to see everything at a glance.

Inspired by [Notchmeister](https://github.com/chockenberry/Notchmeister), [CodexBar](https://github.com/steipete/CodexBar), [RepoBar](https://github.com/steipete/RepoBar), and [NotchDrop](https://github.com/Lakr233/NotchDrop).

## Features

### v0.1.0 — Foundation
- **⚡ Menu Bar App** — No Dock icon. Lives quietly in your status bar.
- **🌟 Notch Glow Animation** — Layered pulsing glow effect rendered over the MacBook Pro notch. Color changes with system state.
- **🔧 Process Monitor** — Auto-detects running `node`, `vite`, `next`, `tsx`, `webpack`, `turbo` dev servers. Groups by project, shows ports, memory usage, and runtime.
- **💀 Zombie Detection** — Highlights processes running for over 24 hours.
- **⚡ Kill Controls** — Kill individual processes or entire project groups with one click.
- **🔄 Auto-refresh** — Updates every 3 seconds.

### Notch Signal Colors
| Color | Meaning |
|-------|---------|
| 🟢 Green pulse | Idle / everything OK |
| 🟢 Fast green | AI agent actively running |
| 🟡 Amber flicker | Agent stalled or slow |
| 🔴 Red flash | Process crashed |
| 🟠 Orange breath | Quota warning |
| 🟣 Purple absorb | File stashed |

### Roadmap
- [ ] **AI Agent Status** — Monitor Claude Code / Cursor agent state via `~/.claude/logs`
- [ ] **AI Usage & Quota** — Token consumption, 5h rolling window, spend tracking
- [ ] **GitHub Status** — CI status, open PRs, local branch state (ahead/behind, dirty)
- [ ] **Music Control** — Now playing via MediaRemote, play/pause/next
- [ ] **Clipboard Manager** — Auto-clean shell commands (strip `$`, flatten multiline)
- [ ] **NotchDrop** — Drag files to notch area to stash temporarily

## Requirements

- macOS 14.0 Sonoma or later
- MacBook Pro with notch (M1 Pro/Max/Ultra or later) for the notch glow effect
- Menu bar functionality works on all Macs

## Installation

### Download (Recommended)
Download `ApexNotch-v0.1.0.dmg` from the [latest release](../../releases/latest), open it, and drag ApexNotch to your Applications folder.

> **Note:** ApexNotch is not notarized yet. On first launch, right-click the app and select "Open" to bypass Gatekeeper.

### Build from Source
```bash
# Requirements: Xcode 15+, XcodeGen
brew install xcodegen

git clone https://github.com/Conn-Ho/ApexNotch
cd ApexNotch
xcodegen generate
xcodebuild -project ApexNotch.xcodeproj -scheme ApexNotch -configuration Release \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build
```

## Architecture

```
ApexNotch/
├── App/                    # @main entry + AppDelegate
├── MenuBar/                # NSStatusItem + NSPopover
├── NotchOverlay/           # Transparent notch window + animations
├── Features/
│   ├── ProcessMonitor/     # Dev process scanning & management
│   └── (more coming)
└── Shared/                 # AppState, AppSignal, ShellRunner
```

Each feature is a self-contained module. `AppState` aggregates all services and drives the notch animation via `AppSignal`.

## Contributing

PRs welcome. Each feature module is independent — pick a roadmap item and go.

## License

MIT © [Conn Ho](https://github.com/Conn-Ho)
