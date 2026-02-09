# TokenShepherd

## What This Is

Mac menu bar app for Claude Code usage monitoring. Native Swift/AppKit with NSMenu + SwiftUI views.

**Status:** Working prototype — menu bar app shows real-time quota data.

## Philosophy

1. **User-aligned:** Anthropic wants you to upgrade. We want you to optimize.
2. **Contextual value:** Information at the right moment beats documentation.
3. **Ship fast, adapt faster:** Claude Code changes. We keep up.

## Tech Stack

- **Menu bar app:** Swift/AppKit (`NSStatusItem` + `NSMenu` + `NSHostingView` with SwiftUI + Charts)
- **Data layer:** Native Swift (URLSession + Keychain via `security` CLI) — no Node.js dependency
- **CLI:** TypeScript (independent tool, `npm run status`)
- **Build:** Swift Package Manager (macOS 14+), npm for TypeScript

## Commands

```bash
make run        # Build everything and launch menu bar app
make build      # Build Swift app only
make cli        # Build TypeScript CLI only
make clean      # Clean Swift build artifacts
npm run status  # CLI quota check
```

## Architecture

```
NSStatusItem (🐑 + dynamic % in menu bar)
  └── NSMenu
      ├── NSMenuItem → WindowRowView (5-Hour: %, bar, reset, pace)
      │   └── submenu → SparklineView (24h history)
      ├── NSMenuItem → WindowRowView (7-Day: %, bar, reset, pace)
      │   └── submenu → SparklineView (7d history)
      ├── separator
      ├── "Show/Hide Details" toggle
      ├── NSMenuItem → DetailView (sonnet, extra usage, plan, refreshed at)
      ├── separator
      ├── Refresh (⌘R)
      ├── separator
      └── Quit (⌘Q)
```

### File Structure
```
macos/Sources/TokenShepherd/
  main.swift              — AppDelegate, NSMenu construction, icon updates
  Models.swift            — All data types (API, domain, auth, history)
  KeychainService.swift   — Read Claude Code OAuth token from macOS Keychain
  APIService.swift        — URLSession GET to Anthropic quota API + token refresh
  QuotaService.swift      — Orchestrator: auth → fetch → history → publish state
  PaceCalculator.swift    — Binding constraint + time-to-limit math
  HistoryStore.swift      — JSONL append/read at ~/.tokenshepherd/history.jsonl
  WindowRowView.swift     — SwiftUI: one quota window (label, %, bar, reset, pace)
  SparklineView.swift     — SwiftUI Charts: minimal line chart
  DetailView.swift        — SwiftUI: Sonnet, extra usage, plan, last refreshed
  StatusBarIcon.swift     — Pure function: QuotaState → icon title + color
```

### Data Flow
```
KeychainService → OAuthCredentials
  → APIService.fetchQuota(token) → APIQuotaResponse
  → QuotaService maps to domain models → @Published QuotaState
  → Combine sink → updateUI() + updateIcon()
  → HistoryStore.append() → ~/.tokenshepherd/history.jsonl
```

### Data Source
- OAuth token from macOS Keychain (where Claude Code stores it)
- Anthropic quota API (`/api/oauth/usage`)
- Auto-refresh on menu open
- History persisted at `~/.tokenshepherd/history.jsonl`

## Key Documents

- `RESEARCH.md` — Product research, market analysis, technical feasibility
- `PRODUCT_DISCOVERY.md` — Product discovery notes
- `CLI_SPEC.md` — CLI specification
- `README.md` — Project overview and setup

## Links

- Domain candidates: tokenshepherd.com, tokenshepherd.app, tokenshepherd.io
