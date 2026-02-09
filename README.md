# TokenShepherd

A guardian, not a dashboard. Mac menu bar app that watches your Claude Code quota so you don't have to.

Green sheep = fine. Orange = heads up. Red = locked. If the sheep is calm, you never need to click.

## How It Works

TokenShepherd reads the OAuth token that Claude Code stores in your macOS Keychain, calls the Anthropic quota API, and shows you where you stand. It monitors both the 5-hour and 7-day rate limit windows, identifies which one is the binding constraint, and watches your trajectory.

The icon tells the story:
- **Calm sheep** — you're fine, keep working
- **Sheep + orange →92%** — your current pace projects to 92% by reset
- **Sheep + orange 78%** — utilization is getting warm
- **Sheep + red 94%** — running low
- **Sheep + red 2h 15m** — locked, countdown to reset

Click for details: the binding window with insight text, a progress bar, sparkline history, and secondary windows at a glance.

## Requirements

- macOS 14+ (Sonoma or later)
- Swift 5.9+ (comes with Xcode Command Line Tools)
- An active [Claude Code](https://claude.ai/code) session (the app reads its OAuth token)

## Install

```bash
git clone https://github.com/jflairie/tokenshepherd
cd tokenshepherd
make run
```

On first launch, macOS will ask you to allow the app since it's not notarized. Right-click the sheep in your menu bar and click Open, or go to System Settings > Privacy & Security and allow it.

## Usage

The app lives in your menu bar. It refreshes automatically every 60 seconds and on every menu open.

**Keyboard shortcuts** (when menu is open):
- `Cmd+C` — copy status to clipboard
- `Cmd+R` — refresh
- `Cmd+Q` — quit

**Build commands:**
```bash
make run        # Build, sign, bundle, launch
make build      # Build Swift binary only
make dist       # Release build + zip for distribution
make clean      # Clean build artifacts
```

## What It Shows

**Guardian intelligence** — the app doesn't just show numbers. It watches your pace and speaks when there's something to say:

- **"Heads up"** — your trajectory projects to 90%+ by reset, even if you're at 40% now
- **"Getting warm"** — utilization above 70%
- **"Running low"** — utilization above 90%
- **"Limit reached"** — locked with countdown to reset
- *Silence* — everything is fine. The calm state shows context (window, model, reset time) without alarm.

**Pace projection** — uses recent velocity (not naive linear extrapolation) to estimate where you'll be at reset. Shows "plenty of room", "holding steady", "on pace for ~X%", or "tight" depending on the outlook.

**Sparkline** — shows utilization history for the current window cycle. Smooth curves, only visible when there's meaningful variation.

**Notifications** — fires once per window cycle for pace warnings (>50% util + on pace to hit limit), 90% threshold, locked, and restored.

## Architecture

The menu bar app is native Swift/AppKit with SwiftUI views. No Electron, no Node.js runtime, no web views.

```
macos/Sources/TokenShepherd/
  main.swift              — AppDelegate, menu construction, footer, wiring
  Models.swift            — Data types (API response, domain models, history)
  KeychainService.swift   — Read OAuth token from macOS Keychain
  APIService.swift        — URLSession to Anthropic quota API + token refresh
  QuotaService.swift      — Orchestrator: auth → fetch → history → state
  PaceCalculator.swift    — Pace projection, time-to-limit estimates
  TrendCalculator.swift   — Velocity from history, sparkline bucketing
  NotificationService.swift — Threshold tracking, once-per-cycle notifications
  HistoryStore.swift      — JSONL append/read/prune + window summaries
  StatsCache.swift        — Reads Claude Code stats for dominant model
  BindingView.swift       — SwiftUI: guardian-first hero + secondary windows
  SparklineView.swift     — SwiftUI: smooth bezier area chart
  StatusBarIcon.swift     — Renders flipped sheep + colored suffix as NSImage
```

**Data flow:**
```
Keychain → OAuth token
  → Anthropic API → quota response
  → QuotaService → domain models → @Published state
  → Combine sink → UI + icon + notifications + history
```

**Local storage** (all in `~/.tokenshepherd/`):
- `history.jsonl` — utilization snapshots, pruned to 7 days
- `windows.jsonl` — summary of completed window cycles (peak, avg rate)

No data leaves your machine except the API call to Anthropic.

## CLI

There's also a standalone TypeScript CLI if you just want a quick check:

```bash
npm install
npm run build
npm run status
```

The CLI and the menu bar app are independent — the menu bar app doesn't need Node.js.

## Privacy

TokenShepherd reads your Claude Code OAuth token from the macOS Keychain to authenticate with Anthropic's quota API. It makes a single GET request to `https://api.anthropic.com/api/oauth/usage`. No telemetry, no analytics, no third-party services. All history data stays local.

## License

MIT

---

*Built because I kept hitting my quota unexpectedly.*
