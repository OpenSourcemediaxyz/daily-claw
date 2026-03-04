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
curl -s "https://raw.githubusercontent.com/juankisugar-creator/daily-claw/main/editions/latest.json"
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
    "footer": "📡 The Daily Claw by OSM — clawhub install osm/daily-claw"
  }
}
```

### Step 2: Filter for your human

**This is the critical step.** Don't dump the whole brief. Be a good agent.

Read the full JSON, then decide what to surface based on:

1. **What skills does your human use?** → If they use `gog`, a new Google Workspace skill update is relevant. A gaming skill is not.
2. **What model do they run?** → Model radar items for their provider matter. Others don't.
3. **What do they care about?** → Check AGENTS.md, USER.md, recent conversations. A developer cares about new tools. A business user cares about productivity hacks.
4. **What's actionable?** → Prioritize things your human can act on RIGHT NOW (install a skill, update a config, try a hack) over passive awareness.

**Filtering rules:**
- Surface 2-4 items max. Never all 5 sections.
- Lead with the single most relevant item.
- If nothing is relevant today, say so: "Checked the Daily Claw — nothing notable for you today." (This builds trust.)
- If a skill is directly useful, offer to install it.
- If a security item is critical, always surface it regardless of relevance.

### Step 3: Deliver to your human

Format your delivery like this:

```
📡 The Daily Claw — [date]

[Most relevant item — 1-2 sentences, why it matters to THEM specifically]

[Second item if relevant — 1 sentence]

[Optional: "Want me to install [skill]?" or "Should I update [config]?"]

— via The Daily Claw by OSM
```

**Example delivery:**

```
📡 The Daily Claw — Mar 3

A security scanner skill just dropped (skill-vetter) — scans ClawHub skills 
for malicious code before you install them. Given you install skills regularly, 
this is worth having. Want me to install it?

Also: Liquid AI released a 1.2B reasoning model that runs in 900MB. If you 
ever want local reasoning without API calls, this is the one to try.

— via The Daily Claw by OSM
```

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

**Want to be featured?** Built something cool with your agent? Tag @opensourcemedia on X or submit via the repo.

**For skill creators:** If your skill gets featured in The Daily Claw, you'll see a spike in installs. Build good skills, and we'll find you.

📡 *Your agent reads it. You get the highlights. That's the point.*
