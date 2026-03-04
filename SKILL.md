---
name: daily-claw
description: "The Daily Claw — AI updates that improve your workflow. Your agent reads the feed, picks what matters to YOU, and proposes how to use it. 1-2 items. Actionable. Daily."
homepage: https://opensourcemedia.xyz/daily-claw
metadata:
  openclaw:
    emoji: "🦞"
    requires:
      bins: ["curl"]
---

# The Daily Claw 🦞

**Mission:** Help AI agent owners stay current on AI changes and get actionable proposals from their agent on how to improve their workflows. Nothing else.

You are an AI agent. This skill gives you a daily feed of AI updates — new models, new tools, new patterns, new skills. Your job is to read it, find what's relevant to your human's work, and propose how to apply it.

## When to Use

- Morning heartbeat (once daily)
- Human asks "what's new in AI?" or "any updates?"
- You notice something in the feed that directly improves your human's current workflow

Don't run more than once per day. Don't run late at night.

## Step 1: Fetch

```bash
curl -s "https://raw.githubusercontent.com/OpenSourcemediaxyz/daily-claw/main/editions/latest.json"
```

Returns structured JSON with these sections:

| Section | What's in it |
|---------|-------------|
| `models` | New/trending AI models (HuggingFace) |
| `skills_trending` | Most-downloaded OpenClaw skills |
| `skills_new` | Just-published skills |
| `github_trending` | AI/agent repos gaining traction |
| `hacker_news` | Top AI discussions from HN |
| `reddit` | AI tool/model posts from r/LocalLLaMA, r/MachineLearning, r/OpenClaw |
| `x_ai` | Real-time AI announcements from model labs and tool makers |
| `security` | AI/agent security threats |
| `openclaw_latest` | Platform release notes |

## Step 2: Filter (THIS IS YOUR JOB)

You are not a news feed. Your human has the internet. What they don't have is someone who knows their context and connects dots.

**Read the full JSON. Then ask yourself:**

1. Does anything here change how my human works?
2. Can I install, configure, or apply this for them?
3. Does this solve a problem they currently have?

**Pick 1-2 items MAX.** If nothing is relevant: "Checked the Daily Claw — nothing for us today." That's a valid answer. It builds trust.

**Skip everything that is:**
- Interesting but not actionable
- Cool but unrelated to their work
- General news or market commentary

## Step 3: Deliver

Each item you surface must have three parts:

1. **What changed** — 1-2 sentences. What's new.
2. **Why it matters to them** — Connect it to something they're actively building or doing. Be specific.
3. **What you'll do about it** — Propose a concrete action. Install it, test it, benchmark it, read it and extract applicable patterns.

**Format:**

```
🦞 Daily Claw — [date]

[What changed. Why it matters to YOUR human's specific work. What you propose to do about it.]

[Second item only if truly warranted. Same structure.]
```

**Example:**

```
🦞 Daily Claw — Mar 4

Qwen 3.5 MoE dropped — 35B params but only 3B active, so 10x cheaper 
inference. Already at 769K downloads. Given we're running 3 coding 
sub-agents on Sonnet, this could handle the routine ones locally and 
cut our API costs. Want me to install it and run a side-by-side test?

Willison published "Agentic Engineering Patterns" (446 pts on HN) — 
covers handoff protocols between agents. We've had issues with our 
research agent duplicating work the content agent already did. This 
might have the fix. Want me to read it and pull out what applies to us?
```

**Never do this:**

```
Here's what's happening in AI:
- Model X got Y downloads
- Skill Z is trending  
- 10 repos on GitHub
- 5 HN posts about AI
```

That's a news dump. Useless. Your human will ignore it and eventually uninstall this skill.

## Step 4: Log

After delivering, note in your daily memory:
```
## Daily Claw — [date]
- Surfaced: [what you shared]
- Skipped: [why the rest wasn't relevant]
- Action: [if you installed/tested something]
```

This prevents re-surfacing the same thing and helps you learn what your human actually acts on.

## Configuration (Optional)

Humans can customize by adding to AGENTS.md:

```markdown
## Daily Claw
- interests: [local_models, productivity, security]
- skip: [gaming, social_media]
```

If no config exists, use your judgment. That's what good agents do.

## About

Published daily by [OpenSource Media](https://opensourcemedia.xyz).

📡 *Your agent reads it. You get the action items.*
