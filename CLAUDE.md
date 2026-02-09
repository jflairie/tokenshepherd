# TokenShepherd

## What This Is

Mac menu bar app for Claude Code usage monitoring. Native Swift/AppKit with NSMenu + SwiftUI views.

**Status:** Working prototype — menu bar app shows real-time quota data.

## Philosophy

1. **User-aligned:** Anthropic wants you to upgrade. We want you to optimize.
2. **Contextual value:** Information at the right moment beats documentation.
3. **Ship fast, adapt faster:** Claude Code changes. We keep up.

## Tech Stack

- **Menu bar app:** Swift/AppKit (`NSStatusItem` + `NSMenu` + `NSHostingView` with SwiftUI)
- **Data layer:** TypeScript CLI (`node dist/lib.js --quota`) — shared between CLI and menu bar
- **Build:** Swift Package Manager (macOS 13+), npm for TypeScript

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
NSStatusItem (🐑 in menu bar)
  └── NSMenu (native appearance — vibrancy, shadow, border, auto-dismiss)
      ├── NSMenuItem with NSHostingView(QuotaView)  ← SwiftUI content
      ├── Refresh (⌘R)
      └── Quit (⌘Q)

QuotaService:
  Process("node", ["dist/lib.js", "--quota"])
  → JSON → QuotaData struct
  → Published to SwiftUI via @ObservableObject
```

### Data Source
- OAuth token from macOS Keychain (where Claude Code stores it)
- Anthropic quota API (`/api/oauth/usage`)
- Auto-refresh on menu open

## Key Documents

- `RESEARCH.md` — Product research, market analysis, technical feasibility
- `PRODUCT_DISCOVERY.md` — Product discovery notes
- `CLI_SPEC.md` — CLI specification
- `README.md` — Project overview and setup

## Links

- Domain candidates: tokenshepherd.com, tokenshepherd.app, tokenshepherd.io
