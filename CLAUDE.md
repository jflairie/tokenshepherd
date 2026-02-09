# TokenShepherd

## What This Is

A guardian, not a dashboard. Mac menu bar app that watches your Claude Code quota so you don't have to. Green sheep = fine. Orange = watch out. Red = locked. If the sheep is calm, you never need to click.

## Philosophy

1. **Guardian, not dashboard:** The shepherd comes to you when something needs attention. Otherwise, everything is fine.
2. **User-aligned:** Anthropic wants you to upgrade. We want you to optimize.
3. **Ship fast, adapt faster:** Claude Code changes. We keep up.

## Tech Stack

- **Menu bar app:** Swift/AppKit (`NSStatusItem` + `NSMenu` + `NSHostingView` with SwiftUI)
- **Data layer:** Native Swift (URLSession + Keychain via `security` CLI) — no Node.js dependency
- **Build:** Swift Package Manager (macOS 14+), .app bundle via Makefile

## Commands

```bash
make run        # Build, sign, bundle as .app, launch
make build      # Build Swift binary only
make dist       # Release build + sign + zip for distribution
make clean      # Clean Swift build artifacts
```

## Architecture

### Three Surfaces

1. **Icon (ambient)** — Calm sheep = fine. Orange `78%` = warm. Red `94%` = low. Red `2h 15m` = locked. 80% of the value lives here.
2. **Notifications (proactive)** — Pace warning, 90% threshold, locked, restored. Each fires once per window cycle.
3. **Menu (on demand)** — Guardian-first hero (verdict when warning, context when calm), progress bar, sparkline, secondary windows, metadata footer.

### File Structure
```
macos/Sources/TokenShepherd/
  main.swift              — AppDelegate, menu construction, footer, wiring
  Models.swift            — All data types (API response, domain, auth, history, trend, window summary)
  KeychainService.swift   — Read Claude Code OAuth token from macOS Keychain
  APIService.swift        — URLSession GET to Anthropic quota API + token refresh
  QuotaService.swift      — Orchestrator: auth → fetch → history → publish state + 60s timer
  PaceCalculator.swift    — Pace projection, time-to-limit, limitAt formatting
  TrendCalculator.swift   — Velocity from history, sparkline bucketing
  NotificationService.swift — UNUserNotificationCenter: threshold tracking per window cycle
  HistoryStore.swift      — JSONL append/read/prune + window summaries (WindowSummaryStore)
  StatsCache.swift        — Reads ~/.claude/stats-cache.json for dominant model (Opus/Sonnet)
  BindingView.swift       — SwiftUI: guardian-first hero + inline % bar + sparkline + secondary windows
  SparklineView.swift     — SwiftUI: smooth bezier area chart (quadratic curves, gradient fill)
  StatusBarIcon.swift     — Renders flipped sheep + colored suffix as single NSImage
```

### Data Flow
```
KeychainService → OAuthCredentials
  → APIService.fetchQuota(token) → APIQuotaResponse
  → QuotaService → domain models → @Published QuotaState
  → Combine sink:
    → HistoryStore.append() → ~/.tokenshepherd/history.jsonl
    → HistoryStore.readForWindow() → TrendCalculator → velocity + sparkline
    → BindingView (guardian hero, bar, sparkline, secondary)
    → StatusBarIcon (sheep + utilization suffix)
    → NotificationService.evaluate()
```

### Guardian Intelligence

The app doesn't just show numbers. It watches your pace and speaks when there's something to say:

| State | Icon | Menu heading | Triggers when |
|---|---|---|---|
| Calm | Sheep (no suffix) | Context: window, model, reset time | Utilization < 70%, no trajectory concern |
| Trajectory | Sheep orange-tinted (no suffix) | "Heads up" | Pace projects to 90%+ at reset, util still < 70% |
| Getting warm | `78%` orange | "Getting warm" | Utilization 70-89% |
| Running low | `94%` red | "Running low" | Utilization 90-99% |
| Locked | `2h 15m` red | "Limit reached" | Utilization 100% |

Icon shows current state (ambient). Menu heading shows full analysis including trajectory (focused attention). Notification bridges the gap — proactive alert, fires once.

### Notification Thresholds
| Trigger | Condition | Fires once per |
|---|---|---|
| Pace warning | `showWarning` true AND util > 50% | window cycle (resetsAt) |
| Running low | Utilization >= 90% | window cycle |
| Locked | Utilization >= 100% | window cycle |
| Restored | Previously locked → unlocked | cycle transition |

### Local Storage

All in `~/.tokenshepherd/`:
- `history.jsonl` — utilization snapshots every 60s, pruned to 7 days
- `windows.jsonl` — summary of completed window cycles (peak, avg rate, was locked)

No data leaves your machine except the API call to Anthropic.

### Key Design Decisions

- **Fuzzy date matching:** API `resetsAt` oscillates by ~1s between fetches. All date comparisons use 60s tolerance.
- **Single NSImage icon:** Sheep emoji flipped via CGContext transform, rendered with colored suffix as one image. No gaps, no confusion with system icons.
- **Guardian-first UI:** Heading shows verdict ("Heads up", "Running low") when there's a warning. Shows context (window type, model, reset time) when calm. The app speaks when it has something to say.
- **Trajectory projection:** Uses trend velocity, not naive linear extrapolation. Projects utilization at reset time. Surfaces in menu insight and notifications — not in the icon (icon shows current state only).

## Key Documents

- `RESEARCH.md` — Product research, market analysis, technical feasibility
- `PRODUCT_DISCOVERY.md` — Product discovery notes
