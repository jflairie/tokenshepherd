# TokenShepherd Product Discovery

**Status:** Discovery & Validation Phase
**Date:** 2026-02-01
**Next Step:** Validate ClaudePilot value proposition

---

## Executive Summary

After deep research into Claude Code usage patterns, user pain points, competitive landscape, and technical feasibility, we've pivoted from the original "usage monitoring" concept to **ClaudePilot** — an autopilot layer for Claude Code that manages quota, context, model choice, and safety automatically.

**Key insight:** Users don't want to MONITOR their usage. They want to NOT WORRY about it.

---

## Table of Contents

1. [Original Idea & Why It Failed](#original-idea--why-it-failed)
2. [Technical Findings](#technical-findings)
3. [Market Research](#market-research)
4. [Competitive Analysis](#competitive-analysis)
5. [User Pain Points](#user-pain-points)
6. [Value Proposition Iterations](#value-proposition-iterations)
7. [Final Proposition: ClaudePilot](#final-proposition-claudepilot)
8. [Validation Plan](#validation-plan)
9. [Open Questions](#open-questions)

---

## Original Idea & Why It Failed

### The Original TokenShepherd Concept

> A Mac menu bar app that monitors Claude Code usage, provides real-time visibility into quota consumption, and teaches users to be more efficient.

### Why It Doesn't Work

| Problem | Evidence |
|---------|----------|
| Free alternative exists | ccusage has 10k GitHub stars, is free, open source |
| Data is already accessible | `/usage` command shows quota in 2 seconds |
| Users don't want dashboards | They want to not worry about usage |
| Neither segment will pay | Flexers want to spend more, Frustrated want more quota |
| Platform risk | Anthropic could add any feature natively |

### The Reframe

**Old:** "See your usage"
**New:** "Stop thinking about usage"

---

## Technical Findings

### Quota Data (API)

**Endpoint:** `GET https://api.anthropic.com/api/oauth/usage`

**Required headers:**
```
Authorization: Bearer {token}
anthropic-beta: oauth-2025-04-20
User-Agent: claude-code/2.1.29
```

**Response structure:**
```json
{
    "five_hour": {
        "utilization": 8.0,
        "resets_at": "2026-02-01T18:00:00.020028+00:00"
    },
    "seven_day": {
        "utilization": 36.0,
        "resets_at": "2026-02-05T12:00:00.020048+00:00"
    },
    "seven_day_sonnet": {
        "utilization": 1.0,
        "resets_at": "2026-02-03T09:00:00.020056+00:00"
    },
    "extra_usage": {
        "is_enabled": false,
        "monthly_limit": null,
        "used_credits": null
    }
}
```

**Authentication:**
- OAuth token stored in macOS Keychain
- Key: `Claude Code-credentials`
- Contains: `accessToken`, `refreshToken`, `expiresAt`, `subscriptionType`, `rateLimitTier`

**Access command:**
```bash
security find-generic-password -s "Claude Code-credentials" -w
```

### Local Data (Files)

**Location:** `~/.claude/`

| File | Contents |
|------|----------|
| `stats-cache.json` | Daily activity, model tokens, session counts |
| `history.jsonl` | Session history with project paths |
| `projects/*/` | Per-session JSONL with message-level token data |

**Per-message token data structure:**
```json
{
  "usage": {
    "input_tokens": 2,
    "cache_creation_input_tokens": 0,
    "cache_read_input_tokens": 27737,
    "output_tokens": 2,
    "service_tier": "standard"
  }
}
```

### What's Available vs. Not

| Data | Available | Source |
|------|-----------|--------|
| Current quota % (5hr, 7day) | Yes | API |
| Reset time | Yes | API |
| Per-message tokens | Yes | Local JSONL |
| Session breakdown | Yes | Local JSONL |
| Cost estimates | Calculated | Local + pricing |
| Model-specific limits | Yes | API |
| Context window usage | Yes | Status line API |

---

## Market Research

### Two Distinct User Segments

#### Segment A: "The Flexers"
- $200-$8k/month users
- Share ccusage screenshots as STATUS SYMBOLS
- Compete on spending ("I'm over 20k dam")
- DON'T want to optimize
- ccusage is their "GitHub commit graph for AI"

**Evidence:**
- Video: "ccusage: The Claude Code cost scorecard that went viral"
- Description: "the next gen git commit graph for showing off how much you're building"
- Comments: "$8.7k? Challenge accepted!" / "I'm over 20k dam"

#### Segment B: "The Frustrated"
- $20-$200/month users
- Hit limits in 1-2 days
- Angry on Reddit/GitHub
- Considering cancellation
- Want MORE QUOTA, not monitoring

**Evidence (GitHub Issues):**
- "5% used from ONE message on 5X Max account"
- "Hit weekly limit in 1-2 days"
- "Reset time changed silently"
- "This feels like bait and switch TWICE"
- "6 days of production a month is not worth your subscription"

### Market Sizing (From Original Research)

| Metric | Estimate |
|--------|----------|
| Claude Pro/Max subscribers | 500k - 2M |
| % who use Claude Code | 5-15% |
| Claude Code active users | 25k - 300k |
| % frustrated by limits | 30-50% |
| Addressable market | 7.5k - 150k users |

### Willingness to Pay

**Perplexity analysis:** "No direct evidence exists of users paying for Claude-specific quota monitors."

**Key insight:** Free tools dominate. Paid tools need to deliver DIFFERENT value, not BETTER dashboards.

---

## Competitive Analysis

### ccusage

**Stats:** 10k GitHub stars, 103 releases, active development

**What it does:**
- Parses local JSONL files
- Daily/weekly/monthly usage reports
- Session breakdown
- Cost calculation (via LiteLLM pricing)
- Statusline integration (beta)

**What it does NOT do:**
- Call quota API (no real-time utilization %)
- Predict time-to-limit
- Provide automation
- Prevent dangerous operations
- Menu bar GUI

**Why it went viral:**
- "Conspicuous consumption scorecard"
- Social sharing / flexing
- Free and open source
- Creator does YouTube interviews

### /usage Command

- Built into Claude Code
- Shows quota % and reset time
- 2 seconds to access
- "Good enough" for most users

### Gap Analysis

| Feature | ccusage | /usage | Opportunity |
|---------|---------|--------|-------------|
| Historical data | Yes | No | Covered |
| Current quota % | No | Yes | Covered |
| Prediction | No | No | **OPEN** |
| Automation | No | No | **OPEN** |
| Safety layer | No | No | **OPEN** |
| Model suggestions | No | No | **OPEN** |
| Context management | No | No | **OPEN** |

---

## User Pain Points

### From GitHub Issues & Reddit (Ranked)

| Rank | Pain Point | Severity |
|------|------------|----------|
| 1 | Context loss after auto-compact | Critical |
| 2 | Permission prompt fatigue | High |
| 3 | Claude ignores CLAUDE.md instructions | High |
| 4 | Dangerous git operations | Critical |
| 5 | Performance degradation over long sessions | High |
| 6 | Hallucinated files and outputs | High |
| 7 | Over-engineering and stubbornness | Medium |
| 8 | Large codebase scaling issues | Medium |
| 9 | Complex MCP configuration | Medium |
| 10 | Subagent coordination issues | Medium |

### Quota-Specific Complaints

- "i used it a little friday a little on saturday and maybe 10 minutes this morning and i hit the weekly limit already"
- "5% used from ONE message on a 5X Max account"
- "they postpone the reset time silently after a week"
- "Cutting off usage mid work-week is like losing your top developer"
- "On chatgpt plus i NEVER had to worry about hitting a limit"

### Root Cause Theory

From GitHub user @fritzo:
> "It appears somewhere around version 2.0.???, Claude Code started eagerly compressing context, long before context limits were reached. I suspect this overly-eager context compression is the root cause of faster Opus consumption."

---

## Value Proposition Iterations

### V1: QuotaGuard (Prediction + Alerts)
**Verdict:** B-tier. Still passive, just information.

### V2: ClaudeStretch (Waste Reduction)
**Verdict:** A-tier. Automation beats observation.

### V3: ClaudeSafe (Safety Layer)
**Verdict:** B+ tier. Real pain, but niche.

### V4: ClaudeCoach (Education)
**Verdict:** C-tier. Commoditized info.

### V5: ClaudeTeams (B2B Analytics)
**Verdict:** A-tier potential, different game.

### V6: ccusage+ (Ecosystem Play)
**Verdict:** B-tier. Safe but limited upside.

### V7: ShipMode (Guardrails Wrapper)
**Verdict:** A-tier. High effort, high potential.

### Synthesis → V8: ClaudePilot
**Verdict:** Best combination of viable elements.

---

## Final Proposition: ClaudePilot

### Positioning

**Name:** ClaudePilot
**Tagline:** "Claude Code on Autopilot"

**One-liner:**
> "Stop managing Claude Code. Let it manage itself."

**Core promise:**
> "ClaudePilot handles the stuff you shouldn't have to think about — quota, context, model choice, safety — so you can just build."

### The Insight

Users don't want dashboards. They want to stop thinking about:
- Will I hit my limit?
- Am I wasting tokens?
- Will Claude break something?
- Is my session bloated?
- Should I use Opus or Sonnet?

**ClaudePilot = anxiety removal through automation**

### Differentiation

| ccusage | ClaudePilot |
|---------|-------------|
| Rearview mirror | Autopilot |
| What happened | Handles it for you |
| You monitor | It manages |
| Information | Automation |
| See problems | Prevent problems |

### Feature Set

#### 1. Quota Autopilot
- Background monitoring via /oauth/usage API
- Pace calculation and time-to-limit prediction
- 70%: "efficiency mode" (prefers Sonnet, warns on big ops)
- 90%: "conservation mode" (blocks Opus unless override)
- Menu bar traffic light: green/yellow/red

#### 2. Context Autopilot
- Tracks session context size
- Detects bloat (>100k tokens)
- Suggests fresh sessions: "Save ~30% on next 10 messages"
- Learns user preferences

#### 3. Model Autopilot
- Detects "simple" tasks
- Suggests Sonnet for appropriate tasks
- Learns from user choices
- Optional auto-switch

#### 4. Safety Autopilot
- Blocks dangerous commands: `git checkout .`, `reset --hard`, `rm -rf`, `push --force`
- Confirmation for main branch commits
- Secret detection in staged files
- Strict mode for production repos

#### 5. Smart Alerts
- Only notifies when ACTION needed
- Batches low-priority suggestions
- Learns what user ignores
- Goal: <3 notifications per day

### UI Concept

```
┌─────────────────────────────────┐
│  🟢  ClaudePilot                │
├─────────────────────────────────┤
│  Quota: 36% used                │
│  Good until: ~Friday 6pm        │
│                                 │
│  Today: Saved 47k tokens        │
│  ├─ Sonnet switches: 3          │
│  └─ Fresh session suggestion: 1 │
│                                 │
│  ⚙️ Settings                    │
└─────────────────────────────────┘
```

**Philosophy:** Status + value delivered. No charts. No history.

### Pricing

| Tier | Price | Features |
|------|-------|----------|
| Free | $0 | Traffic light, basic alerts, 5 suggestions/day |
| Pro | $8/mo or $69/yr | Full autopilot, model switching, safety layer, unlimited |

**ROI story:** $69/year < one month of Max upgrade avoided

### The 10x Moment

**Without ClaudePilot:**
> "Shit, I hit my limit again. I was in the middle of something. How did I burn through it so fast?"

**With ClaudePilot:**
> *[2 hours earlier, small notification]*
> "At current pace, you'll hit your limit at 3pm. ClaudePilot switched to Sonnet for simple tasks and saved 40k tokens. You're now good until 6pm."
>
> *[User never had to do anything]*

### Landing Page Copy (Draft)

```
## Stop babysitting Claude Code.

You're paying $20-200/month for Claude Code.
You shouldn't also have to:

- Constantly check your quota
- Worry about hitting limits mid-task
- Wonder if you're wasting tokens
- Fear Claude will break your repo

**ClaudePilot runs in the background and handles it.**

Auto-manages quota. Auto-suggests efficient choices.
Auto-blocks dangerous commands.

You just build.

[Get ClaudePilot — Free to start]
```

---

## Validation Plan

### Phase 1: Interest Validation (1 week)

**Actions:**
1. Landing page with email capture
2. Reddit post: "Would you use a tool that auto-manages your Claude Code quota?"
3. DM 10 users who complained about limits on GitHub
4. Twitter/X post with value prop

**Success metrics:**
- 100 email signups
- 10 "I'd pay for this" responses
- 0 people saying "Anthropic should build this"

### Phase 2: Prototype Validation (2 weeks)

**If Phase 1 passes:**
1. Build minimal Swift menu bar app
2. Implement quota API + traffic light
3. Add basic prediction ("good until X")
4. Beta test with 10 users

**Success metrics:**
- Daily active usage
- Qualitative feedback on value
- Willingness to pay signal

### Phase 3: MVP Launch (2-3 weeks)

**If Phase 2 passes:**
1. Add model autopilot
2. Add context autopilot
3. Add safety layer
4. Launch on Product Hunt

---

## Open Questions (To Grill)

### Product Questions
1. Is "autopilot" the right framing, or does it feel like loss of control?
2. How accurate can "simple task" detection be without ML?
3. Will users trust auto-switching to Sonnet?
4. Is safety layer valuable enough standalone, or must it be bundled?
5. Does the free tier give away too much?

### Technical Questions
1. How often can we poll /oauth/usage without rate limiting?
2. Can we detect context size without being inside Claude Code?
3. How do we intercept/suggest model switches?
4. What's the best way to integrate with git (hooks vs. wrapper)?

### Market Questions
1. Will frustrated users actually pay, or just complain and wait?
2. Is $69/year the right price point?
3. Should we target power users or mainstream?
4. Is B2B (teams) a better initial market?

### Competitive Questions
1. What if ccusage adds these features?
2. What if Anthropic builds native autopilot?
3. Should we contribute to ccusage instead of competing?

---

## Next Steps

1. **Grill the ClaudePilot proposition** — stress test every assumption
2. **Create landing page** — test interest before building
3. **Reddit validation post** — gauge community response
4. **Technical spike** — verify API polling limits, integration approach

---

## Appendix: Sources

- GitHub Issue #9424: Weekly Usage Limits
- GitHub Issue #9094: Unexpected change in Claude usage limits
- Trustpilot Claude Reviews
- YouTube: "ccusage: The Claude Code cost scorecard that went viral"
- ccusage GitHub: https://github.com/ryoppippi/ccusage
- Claude Code docs via Context7
- Perplexity deep search analysis
- Direct API testing of /oauth/usage endpoint

---

*Document created: 2026-02-01*
*Last updated: 2026-02-01*
