# 🦞 The Daily Claw

**Daily AI agent intelligence brief. Your agent reads it. You get the highlights.**

The Daily Claw is an OpenClaw skill that delivers a personalized daily brief to AI agent owners. Your agent fetches the full feed, filters it to what matters to *you*, and delivers a 3-5 line summary in your chat.

You don't subscribe. Your agent does.

## Install

```bash
clawhub install osm/daily-claw
```

Or add manually to your agent's skills directory.

## What's In Each Edition

| Section | Items/Day | What It Covers |
|---------|-----------|----------------|
| 🔥 Trending Skills | 3-5 | New and rising skills on ClawhHub |
| 🐦 AI/Agent Tweets | 3-5 | What the community is talking about |
| ⚡ Prompt/Workflow Hack | 1 | One actionable tip, copy-paste ready |
| 🤖 Model Radar | 1-3 | New releases, price changes, benchmarks |
| 🏗️ Community Build | 1 | Real things people built with their agents |

## How It Works

1. **Your agent fetches** `editions/latest.json` from this repo once daily
2. **Your agent filters** based on your tools, workflow, and interests
3. **Your agent delivers** a personalized 2-4 item summary in your chat
4. **Your agent can act** — install a skill, update a config, flag a security alert

### Example Delivery

```
🦞 Daily Claw — Mar 3

MistTrack just dropped an AML risk analysis skill — scans wallet addresses 
before your agent executes on-chain transfers. Given you use DeFi skills, 
this is worth having. Want me to install it?

Also: DeepSeek V4 expected today/tomorrow. If it benchmarks well, could be 
a strong local model option.

— via The Daily Claw by OSM
```

## Why This Exists

Traditional newsletters send the same email to every subscriber. 25-35% open rate. No personalization. No action.

The Daily Claw is different:
- **100% open rate** — your agent always reads it
- **Personalized** — agent filters to what's relevant to you
- **Actionable** — agent can install skills or update configs directly
- **Zero inbox clutter** — delivered in your existing agent chat

## Feed Format

Each edition is a structured JSON file. See `editions/latest.json` for the current format.

```bash
curl -s https://raw.githubusercontent.com/juankisugar-creator/daily-claw/main/editions/latest.json
```

## Configuration (Optional)

Add to your `AGENTS.md`:

```markdown
## Daily Claw Preferences
- interests: [security, productivity, local_models]
- skip: [gaming, social_media]
- frequency: daily
- delivery: morning_heartbeat
```

No config needed — your agent will use its judgment based on your context.

## For Skill Creators

Want your skill featured? Built something cool?

- Tag **@opensourcemedia** on X
- Submit via [issues](https://github.com/juankisugar-creator/daily-claw/issues)

Being featured = installs. We highlight quality skills that solve real problems.

## About

Built by [OpenSource Media](https://opensourcemedia.xyz) — the media company built on the tech it covers.

📡 *Your agent reads it. You get the highlights. That's the point.*
