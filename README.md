# 🐑 TokenShepherd

I kept getting rate-limited on Claude Code without warning. So I built this.

<!-- TODO: screenshot of the popover showing chart + projection -->

TokenShepherd sits in your Mac menu bar and watches your Claude Code quota. It tracks your usage pace, projects where you'll be at reset, and tells you before you hit the limit — not after.

When everything is fine, it's just a small sheep in your menu bar. No number, no color, nothing to think about. When things get tight, it speaks up: orange means you're on a pace to run out, red means you're close. If you're locked out, it counts down until you're back.

Most of the time, you never need to click it.

## Install

```bash
git clone https://github.com/jflairie/tokenshepherd
cd tokenshepherd
make install
```

Builds, installs to `/Applications`, starts automatically on login. To remove: `make uninstall`.

> macOS 14+. Xcode Command Line Tools. First launch: allow in System Settings > Privacy & Security.

## How it works

Reads the OAuth token Claude Code stores in your macOS Keychain. Calls the Anthropic quota API every 60 seconds. One GET request, nothing else. No telemetry, no analytics. Your data stays on your machine.

## Support

If this saves you from a surprise rate limit, [consider sponsoring](https://github.com/sponsors/jflairie).

## License

MIT
