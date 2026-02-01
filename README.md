# TokenShepherd

Anthropic doesn't want you to understand your Claude Code usage. Here's why.

## The Uncomfortable Truth

When you hit your quota unexpectedly, you have three options:
1. Wait for reset (Anthropic: neutral)
2. Upgrade Pro → Max for $180/month more (Anthropic: happy)
3. Understand your usage and optimize (Anthropic: loses money)

They will never build detailed usage monitoring. It's against their interests.

## The Problem

From Reddit, Discord, and GitHub — real complaints:

> "Hit 100% in 10-15 minutes"

> "Ran out in 2 hours"

> "$200/month on Max and still hitting limits"

The usage bar fills. You don't know why. You don't know what's eating your tokens. You don't know if Opus was worth it for that task or if Sonnet would've been fine.

## What This Is

A Mac menu bar app that sits between you and your quota:

- **Pace indicator**: "At this rate, you'll hit your limit in 3.5 hours. Reset: Sunday 1pm."
- **Session breakdown**: Which conversations are burning tokens
- **Context warnings**: "This session is at 142k context. Starting fresh would save ~40% on next requests."
- **Model recommendations**: When Opus is worth it, when Sonnet is enough

## The Math

| Without TokenShepherd | With TokenShepherd |
|-----------------------|--------------------|
| Keep hitting limits → Upgrade to Max ($200/mo) | Understand usage → Stay on Pro ($20/mo) |
| Annual cost: $2,400 | Annual cost: $240 + $79 app = $319 |
| **You save: $0** | **You save: $2,081/year** |

The app pays for itself in 13 days.

## Status

Research & validation phase. Not built yet.

**Validation in progress:**
- [ ] Reddit/Discord posts to gauge interest
- [ ] User interviews with people who complained about limits
- [ ] Landing page with email signup

If validation shows demand → MVP in 4-6 weeks.

## Documentation

- [RESEARCH.md](./RESEARCH.md) — Market analysis, technical feasibility, architecture

---

*The information about efficient Claude Code usage exists. Blog posts, Reddit threads, documentation. But you read it, nod, forget, and use Opus anyway. The value isn't the knowledge — it's getting it at the exact moment you need it.*
