# TokenShepherd

## What This Is

Mac menu bar app for Claude Code usage monitoring, efficiency coaching, and cost optimization.

**Status:** Research & Validation Phase

## Philosophy

1. **User-aligned:** Anthropic wants you to upgrade. We want you to optimize.
2. **Contextual value:** Information at the right moment beats documentation.
3. **Ship fast, adapt faster:** Claude Code changes. We keep up.

## Key Documents

- `RESEARCH.md` — Full product research, market analysis, technical feasibility
- `README.md` — Project overview

## Tech Stack (TBD)

Candidates:
- Swift/SwiftUI (native Mac, lightweight)
- Tauri (cross-platform, Rust+web)

## Commands

TBD once development starts.

## Architecture Notes

### Data Sources
1. `~/.claude/` directory (sessions, history)
2. OpenTelemetry metrics (if user enables)
3. CLI output parsing (fallback)

### Resilience Strategy
- Version detection on startup
- Adapter pattern for data parsing
- Graceful degradation if structure changes
- 48-hour turnaround on Claude Code updates

## Current Phase

**Validation (no code yet)**
1. [ ] Reddit/Twitter posts to gauge interest
2. [ ] DM users who complained about limits
3. [ ] Landing page with email signup
4. [ ] Goal: 50+ signups, 3+ "I'd pay" responses

## Links

- Domain candidates: tokenshepherd.com, tokenshepherd.app, tokenshepherd.io
