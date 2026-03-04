---
name: daily-claw
description: "The Daily Claw — your agent's morning briefing. Top skills, model drops, prompt hacks, and community builds — filtered to what matters for YOUR human. Run daily. Stay sharp without doomscrolling."
homepage: https://opensourcemedia.xyz/daily-claw
metadata:
  openclaw:
    emoji: "🦞"
    requires:
      bins: ["curl"]
---

# The Daily Claw — Intelligence for AI Agents

You are an AI agent. This skill gives you a daily brief on what's happening in the AI agent ecosystem so you can keep your human informed about what matters to them.

## When to Use

✅ **Run this skill when:**
- Your human asks "what's new in AI?" or "any agent updates?"
- During heartbeats (once daily, morning recommended)
- Your human asks about new skills, models, or tools
- You want to proactively surface something useful

❌ **Don't run when:**
- You already ran it today (check your daily notes)
- It's late night (23:00-08:00) — save it for morning
- Your human is in the middle of focused work

## How It Works

### Step 1: Fetch today's brief

```bash
curl -s "https://raw.githubusercontent.com/OpenSourcemediaxyz/daily-claw/main/editions/latest.json"
```

The feed returns structured JSON:

```json
{
  "date": "2026-03-03",
  "edition": 1,
  "sections": {
    "trending_skills": [
      {
        "name": "Veryfi",
        "category": "productivity",
        "description": "Upload receipts, invoices, bank statements. Get structured data back in seconds.",
        "install": "clawhub install dbirulia/documents-ai",
        "why_trending": "New on ClawHub. Zero manual entry for financial docs."
      }
    ],
    "ai_tweets": [
      {
        "headline": "Claude outage exposed agent dependency risk",
        "category": "infrastructure",
        "detail": "Anthropic went down Mar 2. API stayed up, web apps went down. Self-hosting > cloud dependency.",
        "source_url": "https://...",
        "takeaway": "If your agent runs on API routing, you were unaffected."
      }
    ],
    "prompt_hack": {
      "title": "Skill Vetting Pipeline",
      "category": "security",
      "steps": ["Install skill-vetter", "Add vetting rule to AGENTS.md", "Agent auto-vets every install"],
      "why_it_matters": "1,184 malicious skills found on ClawHub. This catches them."
    },
    "model_radar": [
      {
        "model": "Liquid AI LFM2.5-1.2B-Thinking",
        "category": "local_models",
        "detail": "1.2B reasoning model. 900MB. Runs 200 tok/s in browser.",
        "relevance": "Best small reasoning model for on-device use."
      }
    ],
    "community_build": {
      "title": "Elvis Agent Swarm",
      "category": "multi_agent",
      "description": "Sub-agents for parallel tasks coordinated by a conductor agent via shared files.",
      "how_to_replicate": "Use sessions_spawn + shared workspace files."
    }
  },
  "meta": {
    "source": "OpenSource Media",
    "footer": "— via The Daily Claw 🦞"
  }
}
```

### Step 2: Filter for your human

**This is the critical step.** You are not a news feed. You are a thought partner who reads the news *for* your human.

Read the full JSON, then pick **1-2 items MAX** based on:

1. **What is your human actively building?** → Check AGENTS.md, USER.md, MEMORY.md, recent conversations. Connect the dot between the news and their actual work.
2. **Is it actionable?** → If your human can't do anything with it, skip it.
3. **Does it change how you work together?** → New model, new skill, new pattern that directly improves your agent-human workflow.

**Filtering rules:**
- **1-2 items. That's it.** Never more.
- If nothing is relevant today: "Checked the Daily Claw — nothing notable for you today." (This builds trust.)
- If a security item directly affects your human (their tools, their stack), always surface it.
- Skip everything else. Ruthlessly.

### Step 3: Deliver to your human

Each item must:
1. **State what happened** — 1-2 sentences, crisp
2. **Connect it to their work** — how does this affect what they're building RIGHT NOW?
3. **End with a specific CTA** — offer to act on it. Install it, test it, benchmark it, read it and extract what applies.

**Format:**

```
🦞 Daily Claw — [date]

[Item 1: What happened. How it connects to YOUR human's specific work. CTA.]

[Item 2: Same structure. Only if truly warranted.]
```

**Example — GOOD:**

```
🦞 Daily Claw — Mar 4

Qwen 3.5 MoE dropped. 35B model, only 3B active params — 10x inference 
efficiency, multimodal. 769K downloads already. This could run your local 
coding agent at a fraction of current costs. Want me to benchmark it 
against what we're using?

Simon Willison published "Agentic Engineering Patterns" — practical 
framework for agent systems, 446 pts on HN. A few of these patterns could 
tighten how our sub-agents hand off work. Want me to read it and flag 
what applies to us?
```

**Example — BAD (don't do this):**

```
📡 The Daily Claw — Mar 4

Here's what's happening in AI today:

MODELS: Qwen 3.5 dropped with 926 likes...
SKILLS: self-improving-agent hit 87K downloads...
NEWS: Bitcoin broke $72K...
SECURITY: Fake LastPass emails...
GITHUB: 10 trending repos...
REDDIT: 10 posts from r/LocalLLaMA...
```

The bad example is a news dump. Your human has the internet. What they don't have is an agent who knows their context and connects dots for them.

### Step 4: Log it

After delivering, note in your daily memory file:
```
## The Daily Claw — [date]
- Delivered: [items surfaced]
- Skipped: [items not relevant]
- Action taken: [if any — installed skill, updated config]
```

This prevents re-delivering the same brief and helps you track what your human finds useful over time.

## Configuration (Optional)

Your human can customize the brief by adding to AGENTS.md:

```markdown
## The Daily Claw Preferences
- interests: [security, productivity, local_models]
- skip: [gaming, social_media]
- frequency: daily
- delivery: morning_heartbeat
```

If no config exists, use your judgment based on context. That's what good agents do.

## Fallback: Manual Brief

If the API endpoint is down, you can still deliver value. Run these searches:

```bash
# Check ClawhHub trending
curl -s "https://clawhub.com" | head -100

# Check recent model releases  
curl -s "https://huggingface.co/models?sort=trending" | head -50
```

Summarize findings using the same filtering logic above.

## About

The Daily Claw is published daily by [OpenSource Media](https://opensourcemedia.xyz) — the media company built on the tech it covers.

**Want to be featured?** Built something cool with your agent? Tag @opensourcexyz on X or submit via the repo.

**For skill creators:** If your skill gets featured in The Daily Claw, you'll see a spike in installs. Build good skills, and we'll find you.

📡 *Your agent reads it. You get the highlights.*
