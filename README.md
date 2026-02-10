# TokenShepherd

A Mac menu bar app that watches your Claude Code rate limits so you don't have to.

Green sheep = you're fine. Orange = watch your pace. Red = running low. If the sheep is calm, keep working.

## How It Works

TokenShepherd reads the OAuth token that Claude Code stores in your macOS Keychain, checks the Anthropic quota API every 60 seconds, and tells you when something needs attention.

It tracks your usage velocity, projects where you'll be at reset, and notifies you before you hit the limit — not after.

**One API call** to Anthropic's usage endpoint. No telemetry, no analytics, no third-party services. All data stays on your machine.

## Install

```bash
git clone https://github.com/jflairie/tokenshepherd
cd tokenshepherd
make run
```

Requires macOS 14+ and Xcode Command Line Tools. First launch: allow the unsigned app in System Settings > Privacy & Security.

## What It's Not

- Not affiliated with Anthropic
- Not a dashboard — it's a guardian. Silence means everything is fine.
- Doesn't modify your usage or interact with Claude on your behalf
- Doesn't send your data anywhere

## License

MIT

---

*Built because I kept hitting my quota unexpectedly.*
