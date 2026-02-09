# TokenShepherd

**A guardian, not a dashboard.** Mac menu bar app that watches your Claude Code quota so you don't have to.

If the sheep is calm, you never need to click.

<br>

## The Icon Tells the Story

```
 🐑          All good. Keep working.

 🐑 78%      Getting warm.  (orange)

 🐑 94%      Running low.   (red)

 🐑 2h 15m   Locked.        (red)
```

Nothing, number, countdown. Glance at the menu bar, know where you stand.

<br>

## Install

```bash
git clone https://github.com/jflairie/tokenshepherd
cd tokenshepherd
make run
```

> macOS 14+ required. Swift 5.9+ comes with Xcode Command Line Tools.
>
> First launch: macOS will ask you to allow the unsigned app.
> System Settings → Privacy & Security → Allow.

<br>

## What You'll See

### When Everything Is Fine

```
┌─────────────────────────────────────┐
│                                     │
│  44%  ████████████░░░░░░░░░░░░░░░░  │
│  ▁▁▂▃▃▃▄▅▅▅▅▅▆▆▆▆                  │
│                                     │
│  5-hour · Opus · resets ~3:42 PM    │
│                                     │
│  ─────────────────────────────────  │
│  7-day  12%  ██░░░░░░  resets Wed   │
│                                     │
├─────────────────────────────────────┤
│  ↻  Copy status  Dashboard ↗  30s  │
└─────────────────────────────────────┘
```

No alarm. Context only — which window, which model, when it resets. The sparkline shows your history for this cycle.

### When the Guardian Speaks

```
┌─────────────────────────────────────┐
│                                     │
│  Heads up                           │
│  On pace to hit ~92% by reset       │
│                                     │
│  44%  ████████████░░░░░░░░░░░░░░░░  │
│  ▁▁▂▃▃▃▄▅▅▅▅▅▆▆▆▆▇▇▇              │
│                                     │
│  5-hour · Opus · resets ~3:42 PM    │
│                                     │
│  ─────────────────────────────────  │
│  7-day  12%  ██░░░░░░  resets Wed   │
│                                     │
├─────────────────────────────────────┤
│  ↻  Copy status  Dashboard ↗  30s  │
└─────────────────────────────────────┘
```

The app watches your velocity and projects where you'll be at reset. If the trajectory looks bad, it tells you — even when utilization is low.

### When You're Locked

```
┌─────────────────────────────────────┐
│                                     │
│  Limit reached                      │
│  Back in 2h 15m (~5:30 PM)         │
│                                     │
│  ████████████████████████████████░  │
│                                     │
│  5-hour · resets ~5:30 PM           │
│                                     │
│  ─────────────────────────────────  │
│  7-day  67%  ██████████░░░  Wed     │
│                                     │
├─────────────────────────────────────┤
│  ↻  Copy status  Dashboard ↗  30s  │
└─────────────────────────────────────┘
```

<br>

## Guardian Intelligence

The app doesn't just show numbers. It watches your pace and speaks when there's something to say.

| State | Icon | What it means |
|:------|:-----|:--------------|
| **Calm** | 🐑 | You're fine. Keep working. |
| **Warm** | 🐑 78% | Utilization above 70% |
| **Low** | 🐑 94% | Utilization above 90% |
| **Locked** | 🐑 2h 15m | Limit hit. Countdown to reset. |

**Silence is a feature.** Most of the time the icon is a calm sheep. No number, no color, no noise. That's the point — you only look when there's something to see.

**Notifications** fire once per window cycle:
- Pace warning — on track to hit the limit
- 90% threshold — running low
- Locked — limit reached
- Restored — you're back

<br>

## How It Works

TokenShepherd reads the OAuth token that Claude Code stores in your macOS Keychain, calls the Anthropic quota API, and monitors both the **5-hour** and **7-day** rate limit windows.

It identifies which window is the **binding constraint** (the one that matters right now), tracks your velocity, and projects where you'll be at reset.

```
Keychain → OAuth token
  → Anthropic API (/api/oauth/usage)
  → Binding constraint detection
  → Pace projection (velocity, not naive linear)
  → Icon + menu + notifications
```

Refreshes every 60 seconds and on every menu open.

<br>

## Privacy

One GET request to `https://api.anthropic.com/api/oauth/usage`. That's it.

No telemetry. No analytics. No third-party services. All history stays on your machine.

<br>

## License

MIT

---

*Built because I kept hitting my quota unexpectedly.*
