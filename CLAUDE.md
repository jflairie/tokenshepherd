# TokenShepherd

## What This Is

A guardian, not a dashboard. Mac menu bar app that watches your Claude Code quota so you don't have to. Green sheep = fine. Orange = watch out. Red = locked. If the icon is green, you never need to click.

**Status:** Working prototype — ambient monitoring with notification system wired (needs app signing for notifications to fire).

## Philosophy

1. **Guardian, not dashboard:** The shepherd comes to you when something needs attention. Otherwise, everything is fine.
2. **User-aligned:** Anthropic wants you to upgrade. We want you to optimize.
3. **Ship fast, adapt faster:** Claude Code changes. We keep up.

## Tech Stack

- **Menu bar app:** Swift/AppKit (`NSStatusItem` + `NSMenu` + `NSHostingView` with SwiftUI)
- **Data layer:** Native Swift (URLSession + Keychain via `security` CLI) — no Node.js dependency
- **CLI:** TypeScript (independent tool, `npm run status`)
- **Build:** Swift Package Manager (macOS 14+), .app bundle via Makefile

## Commands

```bash
make run        # Build, bundle as .app, launch (notifications enabled)
make build      # Build Swift binary only
make bundle     # Create .app bundle from built binary
make cli        # Build TypeScript CLI only
make clean      # Clean Swift build artifacts
npm run status  # CLI quota check
```

## Architecture

### Three Surfaces

1. **Icon (ambient)** — Green sheep = fine. Orange + % = watch out. Red + countdown = locked. 80% of the value.
2. **Notifications (proactive)** — Pace warning, 90% threshold, locked, restored. Each fires once per window cycle.
3. **Menu (on demand)** — Binding constraint hero, compact non-binding, metadata footer. Quick confirmation only.

```
NSStatusItem (🐑 + dynamic % in menu bar)
  └── NSMenu
      ├── NSMenuItem → BindingView (hero %, bar, insight, non-binding compact, metadata)
      ├── separator
      ├── Footer: "Refresh ⌘R          Quit ⌘Q"
      └── Hidden NSMenuItems for keyboard shortcuts
```

### File Structure
```
macos/Sources/TokenShepherd/
  main.swift                — AppDelegate, NSMenu construction, icon updates, FooterView
  Models.swift              — All data types (API, domain, auth, history)
  KeychainService.swift     — Read Claude Code OAuth token from macOS Keychain
  APIService.swift          — URLSession GET to Anthropic quota API + token refresh
  QuotaService.swift        — Orchestrator: auth → fetch → history → publish state + 60s background timer
  PaceCalculator.swift      — Pace projection, time-to-limit, limitAt formatting
  NotificationService.swift — UNUserNotificationCenter: threshold tracking per window cycle
  HistoryStore.swift        — JSONL append/read at ~/.tokenshepherd/history.jsonl
  BindingView.swift         — SwiftUI: binding hero + non-binding compact + metadata footer
  StatusBarIcon.swift       — Pure function: QuotaState → icon title + color
```

### Data Flow
```
KeychainService → OAuthCredentials
  → APIService.fetchQuota(token) → APIQuotaResponse
  → QuotaService maps to domain models → @Published QuotaState
  → Combine sink → updateUI() + updateIcon() + NotificationService.evaluate()
  → HistoryStore.append() → ~/.tokenshepherd/history.jsonl
```

### Notification Thresholds
| Trigger | Condition | Fires once per |
|---|---|---|
| Pace warning | `showWarning` true AND util > 50% | window cycle (resetsAt) |
| Running low | Utilization ≥ 90% | window cycle |
| Locked | Utilization ≥ 100% | window cycle |
| Restored | Previously locked → unlocked | cycle transition |

### Data Source
- OAuth token from macOS Keychain (where Claude Code stores it)
- Anthropic quota API (`/api/oauth/usage`)
- Auto-refresh on menu open + 60s background timer
- History persisted at `~/.tokenshepherd/history.jsonl`

## Key Documents

- `RESEARCH.md` — Product research, market analysis, technical feasibility
- `PRODUCT_DISCOVERY.md` — Product discovery notes
- `CLI_SPEC.md` — CLI specification
- `README.md` — Project overview and setup

## Links

- Domain candidates: tokenshepherd.com, tokenshepherd.app, tokenshepherd.io
