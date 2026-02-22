# TokenShepherd

Mac menu bar app that watches your Claude Code quota. Calm sheep = fine. Orange/red sheep = watch out. Dead sheep = locked.

## Commands

```bash
make run        # Build, sign, bundle as .app, launch (dev)
make install    # Release build → /Applications + LaunchAgent (auto-start on login)
make uninstall  # Remove from /Applications + LaunchAgent
make build      # Build Swift binary only
make dist       # Release build + sign + zip for distribution
make clean      # Clean Swift build artifacts
```

## Always Do

- Read `docs/architecture.md` before modifying any file — understand data flow and state derivation first.
- Derive state through `ShepherdState.from()` in `DesignSystem.swift` — single source of truth for state, color, severity.
- Use `security` CLI for keychain access — never `SecItemCopyMatching` (triggers password dialog).
- Ad-hoc sign with `codesign --sign -` — no Hardened Runtime, no entitlements.
- Use 60s tolerance for all `resetsAt` date comparisons (API oscillates by ~1s).
- Preserve stale data when token expires — show last known quota, bootstrap from last history entry on restart.
- Keep icon sheep-only — no text suffix in menu bar.
- Color Pace numbers by per-window state. Now/Resets use `.secondary`/`.tertiary`.
- Icon reflects worst window by `ShepherdState.severity`.

## Never Do

- Never use Hardened Runtime or sandbox entitlements — triggers ghost TCC prompts on non-notarized apps.
- Never spawn subprocesses (e.g., `claude --print`) — macOS attributes child TCC accesses to parent.
- Never use `SecItemCopyMatching` — use `security find-generic-password` instead.
- Never launch the binary directly in LaunchAgent — use `open -W` for proper macOS app context.
- Never skip `launchctl unload` before reinstalling — KeepAlive restarts the app mid-install.

## Architecture (Brief)

- **Swift/AppKit** menu bar app (`NSStatusItem` + `NSMenu` + `NSHostingView` with SwiftUI). macOS 14+.
- **Two surfaces:** Icon (ambient, 80% of value) and Menu (on-demand table hero).
- **State flows:** Keychain → API → QuotaService → HistoryStore → TrendCalculator → ShepherdState (per window) → UI.
- **Local storage:** `~/.tokenshepherd/` (history.jsonl, windows.jsonl). No data leaves your machine except the Anthropic API call.
- **Full reference:** `docs/architecture.md` (file structure, data flow, state table, projection logic, design decisions).
