# TokenShepherd

Real-time Claude Code quota monitoring. See what `/usage` doesn't show you.

```
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

## Installation

```bash
# Clone and install
git clone https://github.com/your-username/tokenshepherd
cd tokenshepherd
npm install

# Run
npm run status

# Or with npx (after building)
npm run build
npx ts status
```

**Requirements:**
- Node.js 18+
- macOS (uses Keychain for credentials)
- Logged into Claude Code (`claude` CLI)

## Usage

```bash
# Show quota status (default)
ts status

# Raw JSON output
ts status --raw

# Help
ts --help
```

## How It Works

1. Reads OAuth token from macOS Keychain (where Claude Code stores it)
2. Calls Anthropic's quota API (`/api/oauth/usage`)
3. Displays real-time utilization percentages

No data leaves your machine except the API call to Anthropic.

## What's Next

If this is useful, planned features:
- [ ] Pace calculation ("At this rate, hits limit at 6pm")
- [ ] `ts watch` — live updating display
- [ ] Menu bar app with traffic light
- [ ] Notifications at 70%, 90%

## Feedback

Found this useful? Have ideas? [Open an issue](https://github.com/your-username/tokenshepherd/issues) or DM me.

---

*Built because I kept hitting my quota unexpectedly.*
