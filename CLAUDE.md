# TokenShepherd

## What This Is

A guardian, not a dashboard. Mac menu bar app that watches your Claude Code quota so you don't have to. Calm sheep = fine. Orange/red sheep = watch out. Dead sheep = locked. If the sheep is calm, you never need to click.

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
make run        # Build, sign, bundle as .app, launch (dev)
make install    # Release build → /Applications + LaunchAgent (auto-start on login)
make uninstall  # Remove from /Applications + LaunchAgent
make build      # Build Swift binary only
make dist       # Release build + sign + zip for distribution
make clean      # Clean Swift build artifacts
```

## Architecture

### Three Surfaces

1. **Icon (ambient)** — Sheep only, no text. Calm = plain (template). Orange = trajectory/warm. Red = low. Dead (flipped, 12% opacity) = locked. 80% of the value lives here.
2. **Notifications (proactive)** — Pace warning, 90% threshold, locked, restored. Each fires once per window cycle.
3. **Menu (on demand)** — Dual-window table hero (both 5h and 7d, independently colored), collapsible details (Sonnet 7d, extra usage — hidden when empty), metadata footer.

### File Structure
```
macos/Sources/TokenShepherd/
  main.swift              — AppDelegate, menu construction, ShepherdState wiring, footer
  Models.swift            — All data types (API response, domain, auth, history, trend, window summary) + shared formatTime
  DesignSystem.swift      — ShepherdState enum: single derivation point for state, color, chart color, severity
  KeychainService.swift   — Read Claude Code OAuth token from macOS Keychain
  APIService.swift        — URLSession GET to Anthropic quota API + token refresh
  QuotaService.swift      — Orchestrator: auth → fetch → history → publish state + 60s timer
  PaceCalculator.swift    — Pace projection, time-to-limit, limitAt formatting
  TrendCalculator.swift   — Velocity from history (trend-based projection input)
  NotificationService.swift — UNUserNotificationCenter: threshold tracking per window cycle
  HistoryStore.swift      — JSONL append/read/prune + window summaries (WindowSummaryStore)
  StatsCache.swift        — Reads ~/.claude/stats-cache.json for token summary (today/yesterday/7d counts + dominant model)
  BindingView.swift       — SwiftUI: table-layout hero (Pace/Now/Resets rows × 5h/7d columns) + collapsible details
  StatusBarIcon.swift     — Sheep-only icon: idle(dimmed)/calm/tinted/dead, no suffix text
```

### Data Flow
```
KeychainService → OAuthCredentials
  → APIService.fetchQuota(token) → APIQuotaResponse
  → QuotaService → domain models → @Published QuotaState
  → Combine sink:
    → HistoryStore.append() → ~/.tokenshepherd/history.jsonl
    → For BOTH windows: readForWindow() → TrendCalculator → trend → projectAtReset()
    → Per-window ShepherdState.from() → independent coloring
    → Icon/notifications = worst state (by severity)
    → BindingView (table hero: Pace/Now/Resets × 5h/7d)
    → DetailsContentView (sonnet 7d, extra usage — hidden when empty)
    → StatusBarIcon (sheep: calm/tinted/dead based on worst state)
    → NotificationService.evaluate()
```

### ShepherdState — Per-Window, Independent Color

`ShepherdState` enum in `DesignSystem.swift` derives state per window. Each window gets its own state and color. Icon uses the worst (highest `severity`).

| State | Condition | Color | Severity |
|---|---|---|---|
| Idle | window expired | `.primary` (dimmed icon) | -1 |
| Calm | util < 70%, no trajectory | `.primary` | 0 |
| Trajectory | projected ≥ 70%, util < 70% | `.orange` | 1 |
| Warm | util 70-89%, projected < 90% | `.orange` | 2 |
| Low | util ≥ 90% OR projected ≥ 90% | `.red` | 3 |
| Locked | util ≥ 100% | `.red` | 4 |

**Table-layout hero:** Row labels (Pace/Now/Resets) on the left, 5h and 7d columns on the right. Pace row leads — 22pt bold projection numbers, independently colored by per-window state. Now row shows current utilization as grounding context. Resets row shows time. When both windows are expired, shows "Standing by" (dimmed). Pace shows em-dash placeholder when projection isn't meaningfully above current (< 5pp) or window is near reset.

**Color hierarchy:** Only the pace number gets state color. Everything else is `.secondary`/`.tertiary`.

**Projection calculation:** `projectAtReset()` in main.swift — extracted function, called for both windows. Rate-based (whole window average) as baseline, trend-based (recent velocity) upgrades if higher. Takes the max — more conservative warning. Guardrails: (1) Proportional cap: project at most N× observation span — 4× for 5h, 1.7× for 7d. (2) Minimum evidence for red: 15+ min of data to push above 90%.

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
- **Sheep-only icon:** No text suffix in menu bar. Sheep emoji flipped via CGContext transform. Calm = `isTemplate: false` (plain emoji). Tinted = `.sourceAtop` blend at 60% alpha for vibrancy. Dead = flipped vertically + 12% alpha.
- **Table-layout hero:** Pace/Now/Resets rows × 5h/7d columns. Pace row has the big 22pt numbers (projection at reset). Now row grounds with current utilization. Resets row shows deadline. No "binding window" — both windows visible at a glance, independently colored. Pace shows em-dash when projection isn't meaningful (< 5pp above current, window near reset, expired, or locked).
- **Worst-window icon:** Icon sheep reflects whichever window has highest severity. `ShepherdState.severity` property (0=calm → 4=locked) determines ordering.
- **Collapsible details:** Collapsed by default. Shows Sonnet 7d utilization and extra usage spend. Toggle hidden entirely when there's no content (static `hasContent` check).
- **Expired window handling:** Expired column shows "—" / "reset" muted. When both expired, hero shows "All clear / Quota just reset" + model label. Updates naturally when API sends fresh window.
- **Dead sheep:** Locked column shows "LOCKED" + "back HH:MM" in red, pace shows em-dash. Icon shows inverted sheep at 12% opacity for worst-window locked.
- **Width:** 280px for all menu content (hero, details toggle, details content). Details padding 24px. Footer at 252px.
- **No Hardened Runtime, no entitlements:** Ad-hoc signed with plain `codesign --sign -`. Hardened Runtime and sandbox entitlements trigger ghost TCC prompts (Photos, Apple Music, network volume, Desktop) on non-notarized apps. Plain ad-hoc signature is sufficient.
- **No subprocess spawning:** Token refresh was previously done by spawning `claude --print "hi"`, but macOS attributes child process TCC accesses to the parent. Claude CLI touches protected directories during init → Desktop/Photos/Music prompts blamed on TokenShepherd. Now we just wait — Claude Code refreshes its own token, we re-read the keychain next cycle.
- **LaunchAgent via `open -W`:** `open` gives proper macOS app context (avoids TCC issues from direct binary launch). `-W` makes `open` wait for exit, so launchd can track it for `KeepAlive` (auto-restart on crash). Install order: `launchctl unload` → kill → remove → copy → load — must unload first or KeepAlive restarts mid-install.
- **Keychain via `security` CLI:** `SecItemCopyMatching` (native API) triggers a scary password dialog for items created by other apps. `security find-generic-password` reads silently from the login keychain. Right trade-off for a non-notarized app.

## Key Documents

- `RESEARCH.md` — Product research, market analysis, technical feasibility
- `PRODUCT_DISCOVERY.md` — Product discovery notes
