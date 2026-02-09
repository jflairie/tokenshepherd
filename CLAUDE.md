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
3. **Menu (on demand)** — Guardian-first hero (verdict when warning, context when calm), unified activity chart with % label, collapsible details, metadata footer.

### File Structure
```
macos/Sources/TokenShepherd/
  main.swift              — AppDelegate, menu construction, footer, wiring
  Models.swift            — All data types (API response, domain, auth, history, trend, window summary) + shared formatTime
  KeychainService.swift   — Read Claude Code OAuth token from macOS Keychain
  APIService.swift        — URLSession GET to Anthropic quota API + token refresh
  QuotaService.swift      — Orchestrator: auth → fetch → history → publish state + 60s timer
  PaceCalculator.swift    — Pace projection, time-to-limit, limitAt formatting
  TrendCalculator.swift   — Velocity from history, sparkline bucketing
  NotificationService.swift — UNUserNotificationCenter: threshold tracking per window cycle
  HistoryStore.swift      — JSONL append/read/prune + window summaries (WindowSummaryStore)
  StatsCache.swift        — Reads ~/.claude/stats-cache.json for token summary (today/yesterday/7d counts + dominant model)
  BindingView.swift       — SwiftUI: guardian-first hero + unified activity chart + collapsible details
  SparklineView.swift     — SwiftUI: smooth bezier area chart (quadratic curves, gradient fill, optional % data label)
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
    → BindingView (guardian hero, activity chart, collapsible details)
    → StatusBarIcon (sheep + projection tint or utilization suffix)
    → NotificationService.evaluate()
```

### Guardian Intelligence

The app doesn't just show numbers. It watches your pace and speaks when there's something to say:

| State | Icon | Menu heading | Triggers when |
|---|---|---|---|
| Calm | Sheep (no suffix) | "Opus · resets in 2h 30m" | Utilization < 70%, no trajectory concern |
| Trajectory | Sheep orange-tinted (no suffix) | "Heads up" | Projected >= 70% at reset, util still < 70% |
| Getting warm | `78%` orange | "Getting warm" | Utilization 70-89% |
| Running low | `94%` red | "Running low" | Utilization 90-99% |
| Locked | `2h 15m` red | "Limit reached" | Utilization 100% |

Icon shows current state (ambient) — sheep tints orange when projected >= 70% but util still < 70%. Menu heading shows model + reset time when calm, verdict when warning. Unified activity chart replaces separate bar + sparkline, with current % as data label. Details section is collapsible — collapsed by default, expands to show both windows, token spend, and extra usage.

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
- **Guardian-first UI:** Heading shows verdict ("Heads up", "Running low") when there's a warning. Shows model + reset time when calm. No window type jargon ("5-hour"/"7-day") — users see reset times, not implementation details.
- **Unified chart:** Single activity chart replaces separate progress bar + sparkline. Current % shown as data label at rightmost point. Removes visual redundancy.
- **Collapsible details:** "Details" row collapsed by default. Expands to show both quota windows, Sonnet 7d, extra usage, and token spend (today/yesterday/7d from stats-cache). Trust layer for curious users.
- **Silent insight:** Insight line only speaks when projected >= 70%. No "holding steady", "plenty of room" — silence IS the calm state.
- **Projection-driven icon:** Sheep tints orange when projected >= 70% at reset (util still < 70%). Higher util uses colored suffix instead. Projection drives both icon AND menu assessment.

## Key Documents

- `RESEARCH.md` — Product research, market analysis, technical feasibility
- `PRODUCT_DISCOVERY.md` — Product discovery notes
