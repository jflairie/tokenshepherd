# Architecture Reference

## Two Surfaces

1. **Icon (ambient)** — Sheep only, no text. Idle = dimmed (35% opacity). Calm = plain (template). Orange = trajectory/warm. Red = low. Dead (flipped, 12% opacity) = locked. 80% of the value lives here.
2. **Menu (on demand)** — Dual-window table hero (both 5h and 7d, independently colored), sync status footer.

## File Structure

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
  HistoryStore.swift      — JSONL append/read/prune + window summaries (WindowSummaryStore)
  StatsCache.swift        — Reads ~/.claude/stats-cache.json for token summary (today/yesterday/7d counts + dominant model)
  BindingView.swift       — SwiftUI: table-layout hero (Pace/Now/Resets rows × 5h/7d columns)
  StatusBarIcon.swift     — Sheep-only icon: idle(dimmed)/calm/tinted/dead, no suffix text
```

## Data Flow

```
KeychainService → OAuthCredentials
  → APIService.fetchQuota(token) → APIQuotaResponse
  → QuotaService → domain models → @Published QuotaState
  → Combine sink:
    → HistoryStore.append() → ~/.tokenshepherd/history.jsonl
    → For BOTH windows: readForWindow() → TrendCalculator → trend → projectAtReset()
    → Per-window ShepherdState.from() → independent coloring
    → Icon = worst state (by severity)
    → BindingView (table hero: Pace/Now/Resets × 5h/7d)
    → StatusBarIcon (sheep: idle/calm/tinted/dead based on worst state)
```

## ShepherdState — Per-Window, Independent Color

`ShepherdState` enum in `DesignSystem.swift` derives state per window. Each window gets its own state and color. Icon uses the worst (highest `severity`).

| State | Condition | Color | Severity |
|---|---|---|---|
| Idle | window expired | `.primary` (dimmed icon) | -1 |
| Calm | util < 70%, no trajectory | `.primary` | 0 |
| Trajectory | projected ≥ 70%, util < 70% | `.orange` | 1 |
| Warm | util 70-89%, projected < 90% | `.orange` | 2 |
| Low | util ≥ 90% OR projected ≥ 90% | `.red` | 3 |
| Locked | util ≥ 100% | `.red` | 4 |

## Table-Layout Hero

Row labels (Pace/Now/Resets) on the left, 5h and 7d columns on the right. Pace row leads — 22pt bold projection numbers, always colored by per-window state. Now row shows current utilization as grounding context. Resets row shows time.

- When both windows expired → "Standing by" (dimmed).
- Pace always shows number in state color: projected % when available, current util % as fallback, em-dash only when expired, locked, or zero utilization.
- Color hierarchy: Pace = state color (primary/orange/red). Now/Resets = `.secondary`/`.tertiary`.

## Projection Calculation

`projectAtReset()` in main.swift — extracted function, called for both windows. Rate-based (whole window average) as baseline, trend-based (recent velocity) upgrades if higher. Takes the max — more conservative warning.

Guardrails:
1. Proportional cap: project at most N× observation span — 4× for 5h, 1.7× for 7d.
2. Minimum evidence for red: 15+ min of data to push above 90%.

## Local Storage

All in `~/.tokenshepherd/`:
- `history.jsonl` — utilization snapshots every 60s, pruned to 7 days
- `windows.jsonl` — summary of completed window cycles (peak, avg rate, was locked)

No data leaves your machine except the API call to Anthropic.

## Design Decisions

- **Fuzzy date matching:** API `resetsAt` oscillates by ~1s between fetches. All date comparisons use 60s tolerance.
- **Sheep-only icon:** No text suffix in menu bar. Sheep emoji flipped via CGContext transform. Calm = `isTemplate: false` (plain emoji). Tinted = `.sourceAtop` blend at 60% alpha for vibrancy. Dead = flipped vertically + 12% alpha.
- **Worst-window icon:** Icon sheep reflects whichever window has highest severity. `ShepherdState.severity` property (-1=idle → 4=locked) determines ordering.
- **Expired window handling:** Expired column shows "—" / "reset" muted. When both expired, hero shows "Standing by" + model label. Updates naturally when API sends fresh window.
- **Stale data preservation:** When token expires and refresh fails, keep showing last known quota data. On restart, bootstrap from last history entry. Only truly-no-data case (first ever launch + expired token) shows "Waiting for Claude."
- **Dead sheep:** Locked column shows "LOCKED" + "back HH:MM" in red, pace shows em-dash. Icon shows inverted sheep at 12% opacity for worst-window locked.
- **Width:** 280px for hero content. Footer at 252px.
- **Footer:** Sync status only ("Synced" when < 90s, "Synced Xm/Xh/Xd ago" when stale). Quaternary styling — metadata, not content. Stale data re-publishes every 60s to keep the label current.
- **No Hardened Runtime, no entitlements:** Ad-hoc signed with plain `codesign --sign -`. Hardened Runtime and sandbox entitlements trigger ghost TCC prompts (Photos, Apple Music, network volume, Desktop) on non-notarized apps. Plain ad-hoc signature is sufficient.
- **No subprocess spawning:** Token refresh was previously done by spawning `claude --print "hi"`, but macOS attributes child process TCC accesses to the parent. Claude CLI touches protected directories during init → Desktop/Photos/Music prompts blamed on TokenShepherd. Now we just wait — Claude Code refreshes its own token, we re-read the keychain next cycle.
- **LaunchAgent via `open -W`:** `open` gives proper macOS app context (avoids TCC issues from direct binary launch). `-W` makes `open` wait for exit, so launchd can track it for `KeepAlive` (auto-restart on crash). Install order: `launchctl unload` → kill → remove → copy → load — must unload first or KeepAlive restarts mid-install.
- **Keychain via `security` CLI:** `SecItemCopyMatching` (native API) triggers a scary password dialog for items created by other apps. `security find-generic-password` reads silently from the login keychain. Right trade-off for a non-notarized app.
