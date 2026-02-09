# TokenShepherd

Real-time Claude Code quota monitoring from your Mac menu bar.

## What It Does

Native macOS menu bar app that shows your Claude Code quota at a glance — 5-hour window, 7-day window, Sonnet usage, reset times. Click the 🐑, see where you stand.

Also includes a CLI:

```bash
$ ts status

╭──────────────────────────────────────────╮
│ ●  TokenShepherd (max)                   │
│                                          │
│ 5-Hour Window                            │
│ █░░░░░░░░░░░░░░░░░░░  7%                 │
│ Resets: tomorrow at 2:00 AM              │
│                                          │
│ 7-Day Window                             │
│ ████████░░░░░░░░░░░░  39%                │
│ Resets: Thursday at 1:00 PM              │
│                                          │
│ ✓ Quota healthy                          │
│ 5hr resets in: 2h 43m                    │
╰──────────────────────────────────────────╯
```

## Why This Exists

**ccusage** shows historical token counts. Good for flexing, not for planning.

**TokenShepherd** shows real-time quota percentages. Know exactly where you stand.

| ccusage | TokenShepherd |
|---------|---------------|
| "You used 847k tokens" | "You're at 39% of 7-day quota" |
| Historical only | Real-time API |
| Token counts | Percentage + reset times |

## Setup

```bash
git clone https://github.com/jflairie/tokenshepherd
cd tokenshepherd
npm install
npm run build
```

**Requirements:**
- macOS 13+ (Ventura or later)
- Node.js 18+
- Swift 5.9+ (comes with Xcode / Command Line Tools)
- Logged into Claude Code (`claude` CLI)

## Menu Bar App

```bash
# Build and run
make run

# Or step by step
make cli      # build TypeScript CLI
make build    # build Swift app
make run      # both + launch
```

Click the 🐑 in your menu bar to see quota. It refreshes automatically when you open the menu.

## CLI

```bash
# Show quota status
ts status

# Raw JSON
ts status --raw

# Help
ts --help
```

## How It Works

1. Reads OAuth token from macOS Keychain (where Claude Code stores it)
2. Calls Anthropic's quota API (`/api/oauth/usage`)
3. Displays real-time utilization percentages

The menu bar app is native Swift/AppKit — `NSStatusItem` + `NSMenu` + SwiftUI views via `NSHostingView`. Looks identical to system menus. The Swift app shells out to the TypeScript CLI for data fetching.

No data leaves your machine except the API call to Anthropic.

## Project Structure

```
tokenshepherd/
├── macos/                        # Native Swift menu bar app
│   ├── Package.swift             # SPM manifest
│   └── Sources/TokenShepherd/
│       ├── main.swift            # App entry, NSStatusItem + NSMenu
│       ├── QuotaView.swift       # SwiftUI quota display
│       └── QuotaService.swift    # Calls node, parses JSON
├── src/                          # TypeScript CLI
│   ├── api/
│   │   ├── auth.ts              # Keychain, token refresh
│   │   └── quota.ts             # Anthropic API client
│   ├── lib.ts                   # Shared core (used by Swift app)
│   └── index.ts                 # CLI entry
├── dist/                         # Compiled TypeScript
└── Makefile                      # Build targets
```

## Feedback

Found this useful? [Open an issue](https://github.com/jflairie/tokenshepherd/issues) or DM me.

---

*Built because I kept hitting my quota unexpectedly.*
