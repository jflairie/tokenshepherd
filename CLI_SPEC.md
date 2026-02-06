# TokenShepherd CLI — Minimal Spec

**Goal:** Validate demand for real-time quota visibility in <1 week
**Scope:** CLI tool that shows what ccusage doesn't — live quota % and time-to-limit prediction

---

## Core Value Proposition

```
What ccusage shows:          What we show:
─────────────────────        ─────────────────────
"You used 847k tokens"       "You're at 36% quota"
"Cost estimate: $12.40"      "At this pace: limit at 6pm"
                             "Reset: Sunday 1pm"
```

**One differentiator:** Real-time quota API + pace prediction

---

## Commands

### `ts status` (primary command)

```
$ ts status

╭─────────────────────────────────────────╮
│  TokenShepherd                          │
├─────────────────────────────────────────┤
│  5-Hour Window                          │
│  ████████░░░░░░░░░░░░  36%              │
│  Resets: 6:00 PM today                  │
│                                         │
│  7-Day Window                           │
│  ████████████░░░░░░░░  58%              │
│  Resets: Sunday 1:00 PM                 │
│                                         │
│  Pace: ~8%/hour                         │
│  At this rate: hits 5hr limit at 6pm    │
╰─────────────────────────────────────────╯
```

### `ts watch` (optional v1.1)

Live updating status (refreshes every 60s):
```
$ ts watch
# Same as status but updates in place
# Ctrl+C to exit
```

### `ts pace` (optional v1.1)

Show pace analysis:
```
$ ts pace

Last hour:    12% consumed
Last 3 hours: 28% consumed (9.3%/hr avg)
Projection:   Will hit 5hr limit in ~4 hours

Suggestion: You're burning fast. Consider:
- Starting fresh sessions (current: 142k context)
- Using Sonnet for simple tasks
```

---

## Technical Architecture

### Data Sources

1. **Quota API** (primary)
   ```
   GET https://api.anthropic.com/api/oauth/usage
   Headers:
     Authorization: Bearer {token}
     anthropic-beta: oauth-2025-04-20
     User-Agent: tokenshepherd/0.1.0
   ```

2. **OAuth Token** (from Keychain)
   ```bash
   security find-generic-password -s "Claude Code-credentials" -w
   ```
   Returns JSON with `accessToken`, `refreshToken`, `expiresAt`

3. **Local Stats** (for pace calculation)
   - `~/.claude/stats-cache.json` — daily token counts
   - `~/.claude/projects/*/` — per-session JSONL for recent activity

### Token Refresh Flow

```
1. Read token from Keychain
2. Check expiresAt
3. If expired, use refreshToken to get new accessToken
4. Call quota API
5. (Optional) Update Keychain with new token
```

**Note:** May need to reverse-engineer refresh endpoint. Fallback: prompt user to run `/usage` in Claude Code to refresh.

---

## File Structure

```
tokenshepherd/
├── src/
│   ├── main.rs           # CLI entry point
│   ├── commands/
│   │   ├── mod.rs
│   │   └── status.rs     # ts status command
│   ├── api/
│   │   ├── mod.rs
│   │   ├── quota.rs      # Anthropic quota API
│   │   └── auth.rs       # Keychain + token refresh
│   ├── display/
│   │   ├── mod.rs
│   │   └── terminal.rs   # Pretty printing
│   └── pace/
│       ├── mod.rs
│       └── calculator.rs # Pace prediction logic
├── Cargo.toml
└── README.md
```

### Dependencies (Rust)

```toml
[dependencies]
clap = { version = "4", features = ["derive"] }    # CLI parsing
reqwest = { version = "0.11", features = ["json"] } # HTTP client
serde = { version = "1", features = ["derive"] }   # JSON parsing
serde_json = "1"
tokio = { version = "1", features = ["full"] }     # Async runtime
chrono = "0.4"                                      # Time handling
keyring = "2"                                       # macOS Keychain
colored = "2"                                       # Terminal colors
```

**Why Rust:**
- Single binary, no runtime
- Fast startup (<50ms)
- Keychain integration via `security-framework`
- Builds credibility with dev audience

**Alternative:** Node.js if faster to ship, but heavier install.

---

## Pace Calculation Algorithm

```
pace_per_hour = (current_utilization - utilization_1hr_ago) / 1

time_to_limit = (100 - current_utilization) / pace_per_hour

# Edge cases:
- If pace <= 0: "Usage stable or decreasing"
- If no historical data: "Not enough data for prediction"
- If already >90%: "Warning: approaching limit"
```

### Data for Pace

Option A: **Poll API periodically, store locally**
```
~/.tokenshepherd/history.json
[
  { "timestamp": "2026-02-01T14:00:00Z", "five_hour": 28, "seven_day": 52 },
  { "timestamp": "2026-02-01T15:00:00Z", "five_hour": 36, "seven_day": 54 }
]
```

Option B: **Infer from local JSONL**
- Parse recent session files
- Calculate tokens used in last hour
- Convert to % based on assumed limits

**Recommendation:** Option A is simpler and more accurate.

---

## MVP Scope (Week 1)

### Must Have
- [ ] `ts status` — show current quota %
- [ ] Keychain token retrieval
- [ ] Pretty terminal output
- [ ] Basic error handling

### Should Have
- [ ] Pace calculation (last hour)
- [ ] Time-to-limit projection
- [ ] Reset time display

### Won't Have (v1)
- [ ] `ts watch` live mode
- [ ] Token refresh (prompt user instead)
- [ ] Historical tracking
- [ ] Notifications
- [ ] GUI

---

## Installation & Distribution

### Phase 1: Manual (validation)
```bash
# Clone and build
git clone https://github.com/user/tokenshepherd
cd tokenshepherd && cargo build --release
cp target/release/ts /usr/local/bin/
```

### Phase 2: Homebrew (if validated)
```bash
brew install tokenshepherd
```

### Phase 3: npm (wider reach)
```bash
npx tokenshepherd status
# or
npm install -g tokenshepherd
```

---

## Success Metrics

### Validation Targets (2 weeks)
- [ ] 50+ GitHub stars
- [ ] 10+ "this is useful" comments
- [ ] 3+ "I'd pay for Pro features"
- [ ] Daily active users returning

### Signals to Build More
- Users asking for notifications
- Users asking for menu bar
- Users asking for git integration

### Signals to Pivot/Stop
- <20 stars after 2 weeks
- "ccusage does this" comments
- No engagement after launch

---

## Launch Plan

### Day 1-3: Build
- Core `ts status` functionality
- Keychain integration
- Basic pace calculation

### Day 4-5: Polish
- Error messages
- README with screenshots
- Demo GIF

### Day 6-7: Launch
- Reddit r/ClaudeAI post
- Hacker News Show HN
- Twitter/X with demo
- DM users who complained about quota on GitHub

### Post-Launch
- Monitor feedback
- Quick iteration on pain points
- Decide: menu bar or pivot?

---

## Open Technical Questions

1. **Token refresh:** Does Anthropic expose a refresh endpoint? If not, fallback to "run /usage to refresh"

2. **Rate limits:** How often can we poll /oauth/usage? Need to test. Likely safe at 1/minute.

3. **Subscription tiers:** Does API response vary by Pro/Max? Need to verify structure is consistent.

4. **Context size:** Can we get this from status line API or only local files?

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Anthropic changes API | Version detection, graceful degradation |
| Keychain access denied | Clear error message, manual token input fallback |
| ccusage adds same feature | Ship fast, differentiate with pace prediction |
| Low adoption | Pivot to ccusage contribution or git hooks |

---

*Spec created: 2026-02-01*
*Target: Ship by 2026-02-08*
