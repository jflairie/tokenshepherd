# TokenShepherd — Product Research Summary

## The Idea

A Mac menu bar app that monitors Claude Code usage, provides real-time visibility into quota consumption, and teaches users to be more efficient — preventing unnecessary upgrades to higher subscription tiers.

---

## The Problem (Validated)

### User Pain Points (from Reddit, Discord, GitHub)

| Pain | Evidence |
|------|----------|
| Surprise quota exhaustion | "Hit 100% in 10-15 minutes", "ran out in 2 hours" |
| Opaque usage bars | Complaints about "bars filling too fast" without understanding why |
| Max subscription frustration | $200/month but still hitting limits, questioning value |
| No visibility into patterns | Users don't know what's consuming their quota |
| Token consumption anxiety | Shock at how fast limits are reached |

### Why Anthropic Won't Fix This

```
User hits limit → Frustrated → Options:
  A) Wait for reset        → Anthropic: neutral
  B) Upgrade Pro → Max     → Anthropic: +$180/month ✅
  C) Use API (pay-as-go)   → Anthropic: variable revenue ✅
  D) Better monitoring     → User stays on lower tier ❌

Conclusion: Anthropic has NEGATIVE incentive to build detailed monitoring.
```

---

## Market Analysis

### Competitive Landscape

| Category | Tools Found | Threat Level |
|----------|-------------|--------------|
| Enterprise API monitoring | Datadog, New Relic, Moesif | None — different market |
| LLM observability | LangWatch, Langfuse, Arize | None — they monitor apps, not personal usage |
| Consumer AI usage tracker | **None** | **Open field** |

**Key finding:** The space is empty for consumer-facing AI usage monitoring.

### Market Sizing (Conservative)

| Metric | Estimate |
|--------|----------|
| Claude Pro/Max subscribers | 500k - 2M |
| % who use Claude Code | 5-15% |
| Claude Code active users | 25k - 300k |
| % frustrated by limits | 30-50% |
| Addressable market | 7.5k - 150k users |

### Unit Economics

| Scenario | Users | Price | MRR | ARR |
|----------|-------|-------|-----|-----|
| Pessimistic | 200 | $5/mo | $1k | $12k |
| Realistic | 500 | $8/mo | $4k | $48k |
| Optimistic | 5,000 | $10/mo | $50k | $600k |

---

## Technical Feasibility

### Data Sources Available

**1. OpenTelemetry (OTEL) Metrics** — Built into Claude Code, requires opt-in:
```bash
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=console  # or prometheus, otlp
```

| Metric | What It Tracks |
|--------|----------------|
| `claude_code.token.usage` | Token consumption by type, user, model |
| `claude_code.cost.usage` | Approximate cost per session |
| `claude_code.session.count` | Adoption and engagement |
| `claude_code.lines_of_code.count` | Productivity (additions/removals) |
| `claude_code.commit.count` | Commits made |
| `claude_code.pull_request.count` | PRs created |

**2. Local Files** — Always available, zero config:
- Sessions stored in `~/.claude/`
- Full message history preserved
- Resumable via `claude --resume`

**3. Built-in Commands:**
- `/cost` — Token usage stats for current session
- `/stats` — Usage patterns (for subscribers)
- `/context` — Context window usage

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    MAC MENU BAR APP                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │   SwiftUI   │    │   SQLite    │    │  Settings   │         │
│  │  Menu Bar   │◄──►│  Storage    │◄──►│   Panel     │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│         ▲                  ▲                                    │
│         │                  │                                    │
│  ┌──────┴──────────────────┴──────┐                            │
│  │       Data Collection Layer     │                            │
│  ├─────────────────────────────────┤                            │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐                      │
│  │  │  OTEL   │  │ ~/.claude│  │  CLI    │                      │
│  │  │ Scraper │  │ Watcher │  │ Parser  │                      │
│  │  └─────────┘  └─────────┘  └─────────┘                      │
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Tech Stack Options

| Format | Tech | Pros | Cons |
|--------|------|------|------|
| Menu bar | Swift/SwiftUI | Native, lightweight | Mac only, learning curve |
| Menu bar | Tauri | Cross-platform, Rust+web | Newer ecosystem |
| Menu bar | Electron | Familiar web tech | Heavy resource use |

---

## Value Proposition

### The Reframe (Key Insight)

**Weak positioning:** "Pay $10/mo for monitoring"
**Strong positioning:** "Stay on Pro. Don't upgrade to Max. Save $180/mo."

```
WITHOUT APP:
"I keep hitting limits" → Frustrated → Upgrade to Max ($200)

WITH APP:
"I understand my usage" → Optimize → Stay on Pro ($20)

SAVINGS: $180/month = $2,160/year
APP COST: $79/year
NET SAVINGS: $2,040/year
ROI: 18x
```

### Two-Pillar Value

| Pillar | Description |
|--------|-------------|
| **Save Money** | Usage monitoring, velocity alerts, session breakdown |
| **Get Smarter** | Learn Claude Code efficiency patterns most don't know |

**Critical insight:** Anthropic will NEVER teach you to use less. That's the moat.

---

## What Users Crave (Ranked)

| Rank | Need | Feature |
|------|------|---------|
| 🥇 | Don't let me hit limit unexpectedly | Real-time pace indicator, velocity alerts |
| 🥈 | Tell me what's eating my quota | Session breakdown, token autopsy |
| 🥉 | Help me decide Opus vs Sonnet | Model switching recommendations |
| 4 | Validate I'm using it well | Efficiency score, ROI framing |
| 5 | Make me a power user over time | Tips, patterns, skill suggestions |

### The Killer Feature

```
⚡ SMART PACE INDICATOR

"You're using tokens 2.3x faster than your sustainable pace.
 At this rate: limit in 3.5 hours.
 Reset: Sunday 1pm.

 💡 This session is context-heavy (142k).
    Starting fresh would save ~40% on next requests."

[Start Fresh Session]  [Switch to Sonnet]  [Dismiss]
```

---

## Recommendations Engine

### Categories

**1. "Stop the Bleeding" (Urgent)**
- Model downgrade suggestions
- Session bloat warnings
- Runaway loop detection
- Quota pace alerts

**2. "Explain What Happened" (Post-mortem)**
- Token autopsy by session
- Expensive session highlights
- Context growth visualization
- Model cost comparisons

**3. "Make Me Smarter" (Behavioral)**
- Fresh session habits
- "Opus for thinking, Sonnet for doing"
- Prime time warnings
- Skill suggestions

**4. "Tell Me I'm Okay" (Validation)**
- Efficiency score
- Value delivered metrics
- ROI framing
- Streaks/achievements

**5. "Predict My Future" (Planning)**
- Project estimation
- Weekly forecast
- Reset countdown
- Buffer recommendations

### Contextual Delivery (The Real Moat)

```
Blog post: "Use Sonnet for simple tasks"
→ User reads, nods, forgets, uses Opus anyway

In-app: "You just used Opus for what looks like a simple task.
        Sonnet would've cost 70% less. Switch next time?"
→ User sees it IN THE MOMENT, changes behavior

The moat isn't the knowledge. It's the delivery at the right moment.
```

---

## Challenges & Risks

### Validated Concerns

| Risk | Severity | Mitigation |
|------|----------|------------|
| Anthropic builds it | Medium | They have negative incentive; ship fast, build loyalty |
| Users won't pay | Medium | Freemium model; strong ROI framing; guarantee |
| Technical fragility (API changes) | Medium | Adapter pattern; version detection; fast updates |
| Distribution is hard | High | Content marketing; community building |
| Free → Paid conversion low | Medium | Demonstrate value in free tier first |
| Subscription fatigue | Medium | $79/year feels like one-time; strong guarantee |

### Challenges Discarded

| Challenge | Why Discarded |
|-----------|---------------|
| "Tips are commoditized" | Value is contextual delivery, not the information itself |
| "Anthropic will change ~/.claude" | Architect for change with adapters; make fast updates a feature |
| "Market too small" | Even pessimistic case ($12k ARR) is meaningful for indie |

---

## Technical Resilience Strategy

### Handling Claude Code Updates

```
Layer 1: Detection
├── Detect Claude Code version on startup
├── Hash ~/.claude structure, compare to known schemas
└── If unknown → flag, don't crash

Layer 2: Abstraction
├── Internal data model (your schema)
├── Adapters per Claude Code version
└── App only talks to internal model

Layer 3: Graceful Degradation
├── Parsing fails? Show "Update required" not crash
├── Core features work, advanced features degrade
└── User isn't blocked, just nudged to update

Layer 4: Rapid Response
├── Monitor Claude Code GitHub releases
├── Auto-notify on new version
├── Ship adapter update within 48 hours
└── Users see: "New Claude Code supported!"
```

**Marketing angle:** "Claude Code updates frequently. We stay current so you don't have to. Every update, we adapt within 48 hours."

---

## Pricing & Positioning

### Pricing Model

| Tier | Price | Features |
|------|-------|----------|
| Free | $0 | Usage dashboard, velocity alerts, session breakdown |
| Pro | $79/year | Everything + recommendations, efficiency score, tips library, weekly insights |

### De-Risk Stack

```
1. ROI framing: "Pays for itself in ONE month of not upgrading"
2. Free tier: "Try monitoring first, no commitment"
3. Guarantee: "30 days, 10x ROI or full refund, no questions"
4. Trust: "Built by a Claude Code power user, not a corp"
```

### Guarantee Copy

> "Use it for 30 days. If you don't save at least $790 (10x your investment) or learn something that changes how you use Claude — full refund. Email me directly. No questions. No friction."

---

## Go-To-Market Strategy

### Phase 1: Free Tool + Content (Weeks 1-4)
- Ship free menu bar app (monitoring only)
- Start Twitter/blog content: "Claude Code efficiency tips"
- Build email list from app downloads
- **Goal:** 1,000 downloads, 500 email signups

### Phase 2: Validate Coaching Value (Weeks 5-8)
- Add "tip of the day" in free app
- Survey users: "Would you pay for deeper coaching?"
- Test with 50 users: early access to Pro
- **Goal:** 20 pre-sales = validation

### Phase 3: Launch Paid Tier (Weeks 9-12)
- Pro app: recommendations, efficiency score, full course
- $79/year positioning
- Launch on Product Hunt
- **Goal:** 200 paying users = $15k ARR

### Distribution Channels

| Channel | Effort | Expected Impact |
|---------|--------|-----------------|
| Reddit r/ClaudeAI | Medium | High if post goes viral |
| Twitter/X content | Ongoing | Builds over time |
| Hacker News | Hard | One-time spike |
| Product Hunt | Medium | Launch day spike |
| Word of mouth | Slow | Compounds over time |

---

## Build Estimate

| Phase | Time | Cost |
|-------|------|------|
| MVP (menu bar + basic monitoring) | 1-2 weeks | $0 |
| Polished v1 (alerts, history, UI) | 2-3 weeks | $0 |
| Landing page + distribution | 1 week | ~$100 |
| **Total to launch** | **4-6 weeks** | **~$100** |

**Note:** Using Claude Code to build accelerates development.

---

## Validation Before Building

### Minimum Viable Test (1 week, no code)

1. Post on Reddit: "Would you pay $79/year for X?"
2. DM 10 people who complained about limits
3. Ask: "What would you pay to not upgrade to Max?"
4. Create landing page with email signup

### Success Metrics

| Signal | Threshold |
|--------|-----------|
| Email signups in 1 week | 50+ |
| Unprompted "I'd pay" responses | 3+ |
| No one says "Anthropic should build this" | 0 |

**If no → Kill the idea. If yes → Build MVP.**

---

## Competitive Moat Summary

| Moat | Type | Durability |
|------|------|------------|
| Contextual tips (right moment) | UX | ✅ Strong |
| Fast adaptation to changes | Operations | ✅ Strong |
| Community trust | Brand | ✅ Builds over time |
| Aligned with user (not Anthropic) | Positioning | ✅ Strong |
| The code itself | Technical | ❌ Weak — copyable |

**The moat is execution + responsiveness + alignment, not code.**

---

## Final Verdict

| Aspect | Assessment |
|--------|------------|
| Pain is real | ✅ Validated in communities |
| Market big enough for indie | ✅ Even pessimistic case works |
| Cost low enough to try | ✅ 4-6 weeks + $100 |
| Structural moat exists | ✅ Anthropic misaligned, you're not |
| Should you build it? | **Yes, after 1-week validation** |

---

## Open Questions

- [ ] Exact ~/.claude file structure documentation
- [ ] OTEL metrics full schema
- [ ] Swift vs Tauri decision
- [ ] Landing page copy A/B tests
- [ ] Pricing sensitivity ($49 vs $79 vs $99)
- [ ] Partnership with Claude Code influencers?

---

*Research conducted: 2026-01-30*
*Sources: Perplexity deep search, Context7 Claude Code docs, community analysis*
