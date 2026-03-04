#!/bin/bash
# The Daily Claw — Curation Pipeline
# Runs daily to generate the next edition
#
# Usage: ./scripts/curate.sh [date]
# Example: ./scripts/curate.sh 2026-03-04
#
# Requires: curl, jq
# Optional: ANTHROPIC_API_KEY for AI-assisted curation

set -euo pipefail

DATE="${1:-$(date +%Y-%m-%d)}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EDITIONS_DIR="$REPO_ROOT/editions"
RAW_DIR="$REPO_ROOT/.raw"

mkdir -p "$EDITIONS_DIR" "$RAW_DIR"

echo "🦞 The Daily Claw — Curating edition for $DATE"
echo ""

# ============================================
# STEP 1: Scrape sources
# ============================================

echo "📡 Step 1: Scraping sources..."

# 1a. ClawhHub trending (placeholder — replace with actual API/scrape)
echo "  → ClawhHub trending skills..."
curl -s "https://clawhub.com" > "$RAW_DIR/clawhub.html" 2>/dev/null || echo "  ⚠️  ClawhHub scrape failed"

# 1b. HuggingFace trending models
echo "  → HuggingFace trending models..."
curl -s "https://huggingface.co/api/models?sort=trending&limit=10" > "$RAW_DIR/hf-trending.json" 2>/dev/null || echo "  ⚠️  HuggingFace scrape failed"

# 1c. Hacker News AI stories
echo "  → Hacker News front page..."
curl -s "https://hacker-news.firebaseio.com/v0/topstories.json" | jq '.[0:20]' > "$RAW_DIR/hn-top.json" 2>/dev/null || echo "  ⚠️  HN scrape failed"

# 1d. OpenClaw GitHub releases
echo "  → OpenClaw releases..."
curl -s "https://api.github.com/repos/openclaw/openclaw/releases?per_page=3" | jq '[.[] | {tag_name, name, published_at, body}]' > "$RAW_DIR/openclaw-releases.json" 2>/dev/null || echo "  ⚠️  OpenClaw releases scrape failed"

echo "  ✅ Scraping complete"
echo ""

# ============================================
# STEP 2: Determine edition number
# ============================================

LAST_EDITION=$(ls -1 "$EDITIONS_DIR"/2*.json 2>/dev/null | sort | tail -1)
if [ -n "$LAST_EDITION" ]; then
    LAST_NUM=$(jq -r '.edition' "$LAST_EDITION" 2>/dev/null || echo "0")
    EDITION=$((LAST_NUM + 1))
else
    EDITION=1
fi

echo "📝 Step 2: Building edition #$EDITION for $DATE"
echo ""

# ============================================
# STEP 3: Generate edition JSON
# ============================================

# If ANTHROPIC_API_KEY is set, use Claude to curate
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    echo "🤖 Step 3: AI-assisted curation (Claude)..."
    
    # Collect all raw data
    RAW_DATA=$(cat "$RAW_DIR"/*.json "$RAW_DIR"/*.html 2>/dev/null | head -c 50000)
    
    # Call Claude API for curation
    PROMPT="You are curating The Daily Claw, a daily intelligence brief for AI agent owners. Based on the following raw data from today's scrapes, create a JSON edition following this exact schema. Pick the most interesting, actionable, and relevant items. Focus on: new skills, model releases, security alerts, and community builds.

Raw data:
$RAW_DATA

Output ONLY valid JSON matching this schema:
{
  \"version\": \"1.0\",
  \"date\": \"$DATE\",
  \"edition\": $EDITION,
  \"published_at\": \"${DATE}T14:00:00Z\",
  \"sections\": {
    \"trending_skills\": [{\"name\": \"\", \"category\": \"\", \"description\": \"\", \"install\": \"\", \"why_trending\": \"\", \"safety\": \"vetted|unvetted\"}],
    \"ai_tweets\": [{\"headline\": \"\", \"category\": \"\", \"detail\": \"\", \"source_url\": \"\", \"takeaway\": \"\"}],
    \"prompt_hack\": {\"title\": \"\", \"category\": \"\", \"steps\": [], \"why_it_matters\": \"\", \"time_to_implement\": \"\"},
    \"model_radar\": [{\"model\": \"\", \"category\": \"\", \"detail\": \"\", \"relevance\": \"\"}],
    \"community_build\": {\"title\": \"\", \"category\": \"\", \"description\": \"\", \"how_to_replicate\": \"\", \"source\": \"\"}
  },
  \"meta\": {\"version\": \"1.0\", \"source\": \"OpenSource Media\", \"footer\": \"🦞 The Daily Claw by OSM — clawhub install osm/daily-claw\", \"next_edition\": \"$(date -d "$DATE + 1 day" +%Y-%m-%d 2>/dev/null || date -v+1d -j -f "%Y-%m-%d" "$DATE" +%Y-%m-%d)\"}
}"

    curl -s https://api.anthropic.com/v1/messages \
        -H "Content-Type: application/json" \
        -H "x-api-key: $ANTHROPIC_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -d "$(jq -n --arg prompt "$PROMPT" '{model: "claude-sonnet-4-6", max_tokens: 4096, messages: [{role: "user", content: $prompt}]}')" \
        | jq -r '.content[0].text' > "$EDITIONS_DIR/$DATE.json"
    
    echo "  ✅ AI curation complete"
else
    echo "⚠️  No ANTHROPIC_API_KEY set. Create edition manually or set the key."
    echo "  Template saved to: $EDITIONS_DIR/$DATE-template.json"
    
    # Generate template
    cat > "$EDITIONS_DIR/$DATE-template.json" << TEMPLATE
{
  "version": "1.0",
  "date": "$DATE",
  "edition": $EDITION,
  "published_at": "${DATE}T14:00:00Z",
  "sections": {
    "trending_skills": [
      {"name": "TODO", "category": "TODO", "description": "TODO", "install": "TODO", "why_trending": "TODO", "safety": "unvetted"}
    ],
    "ai_tweets": [
      {"headline": "TODO", "category": "TODO", "detail": "TODO", "source_url": "TODO", "takeaway": "TODO"}
    ],
    "prompt_hack": {"title": "TODO", "category": "TODO", "steps": ["TODO"], "why_it_matters": "TODO", "time_to_implement": "TODO"},
    "model_radar": [
      {"model": "TODO", "category": "TODO", "detail": "TODO", "relevance": "TODO"}
    ],
    "community_build": {"title": "TODO", "category": "TODO", "description": "TODO", "how_to_replicate": "TODO", "source": "TODO"}
  },
  "meta": {"version": "1.0", "source": "OpenSource Media", "footer": "🦞 The Daily Claw by OSM — clawhub install osm/daily-claw", "next_edition": "TODO"}
}
TEMPLATE
    exit 0
fi

# ============================================
# STEP 4: Validate & publish
# ============================================

echo "✅ Step 4: Validating JSON..."

if jq empty "$EDITIONS_DIR/$DATE.json" 2>/dev/null; then
    echo "  ✅ Valid JSON"
    
    # Update latest.json
    cp "$EDITIONS_DIR/$DATE.json" "$EDITIONS_DIR/latest.json"
    echo "  ✅ latest.json updated"
    
    # Git commit + push
    cd "$REPO_ROOT"
    git add editions/
    git commit -m "🦞 Edition #$EDITION — $DATE" 2>/dev/null || true
    git push origin main 2>/dev/null || echo "  ⚠️  Push failed (run manually)"
    
    echo ""
    echo "🦞 Edition #$EDITION published for $DATE"
    echo "   Feed: https://raw.githubusercontent.com/juankisugar-creator/daily-claw/main/editions/latest.json"
else
    echo "  ❌ Invalid JSON! Check $EDITIONS_DIR/$DATE.json"
    exit 1
fi
