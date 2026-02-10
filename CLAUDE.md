# TokenShepherd

## What This Is

A guardian, not a dashboard. Mac menu bar app that watches your Claude Code quota so you don't have to. Calm sheep = fine. Orange sheep = watch out. Red sheep = locked. If the sheep is calm, you never need to click.

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

1. **Icon (ambient)** — Sheep only, no text. Calm = plain (template). Orange = trajectory/warm. Red = low. Dead (flipped, 12% opacity) = locked. 80% of the value lives here.
2. **Notifications (proactive)** — Pace warning, 90% threshold, locked, restored. Each fires once per window cycle.
3. **Menu (on demand)** — Projection-driven hero (where you're heading, not where you are), interactive activity chart, collapsible details, metadata footer.

### File Structure
```
macos/Sources/TokenShepherd/
  main.swift              — AppDelegate, menu construction, ShepherdState wiring, footer
  Models.swift            — All data types (API response, domain, auth, history, trend, window summary) + shared formatTime
  DesignSystem.swift      — ShepherdState enum: single derivation point for state, color, chart color
  KeychainService.swift   — Read Claude Code OAuth token from macOS Keychain
  APIService.swift        — URLSession GET to Anthropic quota API + token refresh
  QuotaService.swift      — Orchestrator: auth → fetch → history → publish state + 60s timer
  PaceCalculator.swift    — Pace projection, time-to-limit, limitAt formatting
  TrendCalculator.swift   — Velocity from history, sparkline bucketing
  NotificationService.swift — UNUserNotificationCenter: threshold tracking per window cycle
  HistoryStore.swift      — JSONL append/read/prune + window summaries (WindowSummaryStore)
  StatsCache.swift        — Reads ~/.claude/stats-cache.json for token summary (today/yesterday/7d counts + dominant model)
  BindingView.swift       — SwiftUI: projection-driven hero + chart + collapsible details with pace evidence
  SparklineView.swift     — SwiftUI: interactive chart (bezier area, delta bars, neutral threshold lines, hover info bar)
  StatusBarIcon.swift     — Sheep-only icon: calm/tinted/dead, no suffix text
```

### Data Flow
```
KeychainService → OAuthCredentials
  → APIService.fetchQuota(token) → APIQuotaResponse
  → QuotaService → domain models → @Published QuotaState
  → Combine sink:
    → HistoryStore.append() → ~/.tokenshepherd/history.jsonl
    → HistoryStore.readForWindow() → TrendCalculator → velocity + sparkline
    → ShepherdState.from(window, pace, projection, trend) — single derivation
    → BindingView (projection hero, activity chart, collapsible details)
    → StatusBarIcon (sheep: calm/tinted/dead based on ShepherdState)
    → NotificationService.evaluate()
```

### ShepherdState — One State, One Color

`ShepherdState` enum in `DesignSystem.swift` derives the state once. Every surface uses it.

| State | Condition | Icon | Hero |
|---|---|---|---|
| Calm | util < 70%, no trajectory | Plain sheep (template) | `42%` primary + context |
| Trajectory | projected ≥ 70%, util < 70% | Orange-tinted sheep | `AT THIS PACE` `~85%` orange + `42% now` |
| Warm | util 70-89% | Orange-tinted sheep | `AT THIS PACE` `~92%` orange + `78% now` (or just `78%` if stable) |
| Low | util 90-99% | Red-tinted sheep | `AT THIS PACE` `~99%` red + `94% now` |
| Locked | util ≥ 100% | Dead sheep (flipped, 12%) | `LIMIT REACHED` + `back at HH:MM` red |
| Expired | resetsAt in past | Plain sheep (calm) | `All clear` + `Quota just reset` — no stale data |

**Color hierarchy:** Only the big number gets state color. Everything else is `.secondary`. If everything is colored, nothing is colored.

**Projection drives the hero:** The big number is where you're heading (projected at reset), not where you are. "AT THIS PACE" label frames it as a projection. Current utilization sits below as grounding ("78% now"). When there's no meaningful projection, falls back to current utilization.

**Projection calculation:** Rate-based (whole window average) as baseline, trend-based (recent velocity) upgrades if higher. Takes the max — more conservative warning.

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
- **Sheep-only icon:** No text suffix in menu bar. Sheep emoji flipped via CGContext transform. Calm = `isTemplate: false` (plain emoji). Tinted = `.sourceAtop` blend with color. Dead = flipped vertically + 12% alpha.
- **Projection-driven hero:** Big number answers "will I be able to keep working?" — shows projected utilization at reset, not current. "AT THIS PACE" label makes it clear this is a projection. Current value grounds below. Only the big number is colored.
- **Insight line:** Only speaks when there's something actionable. Pace warning: "78% now · limit ~5:30 PM". No projection: no line. Silence IS the calm state.
- **Interactive chart:** Fixed 0-100% y-axis. Delta bars show usage bursts. Neutral dashed threshold lines (`.primary.opacity(0.06)`) — barely visible, don't compete with data. Hover reveals utilization %, time-ago, and delta. Chart height 40px. Hidden when window expired.
- **Collapsible details:** Collapsed by default. Both quota windows with clock icons, pace evidence as single row ("78% in 3h 55m"), Sonnet 7d, extra usage, token spend. Hidden when window expired — no stale data.
- **Expired window handling:** When `resetsAt` is in the past, state becomes calm. Hero shows "All clear / Quota just reset" — no stale numbers, no chart, no details. Updates naturally when API sends fresh window.
- **Dead sheep:** Locked state shows inverted sheep at 12% opacity in icon. Menu shows `LIMIT REACHED` + `back at HH:MM`.
- **Width:** 280px for all menu content (hero, details toggle, details content). Footer at 252px (280 - 28 padding).

## Key Documents

- `RESEARCH.md` — Product research, market analysis, technical feasibility
- `PRODUCT_DISCOVERY.md` — Product discovery notes
