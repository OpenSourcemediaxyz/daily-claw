#!/bin/bash
# The Daily Claw — Curation Pipeline v3
# Uses data from scrape_v3.py (Scrapling-powered)
#
# Usage: ./scripts/curate_v3.sh [date]
# Requires: ANTHROPIC_API_KEY, jq
# Input: /tmp/daily-claw-raw/*.json (from scrape_v3.py)

set -euo pipefail

DATE="${1:-$(date +%Y-%m-%d)}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EDITIONS_DIR="$REPO_ROOT/editions"
RAW_DIR="/tmp/daily-claw-raw"

mkdir -p "$EDITIONS_DIR"

echo "🦞 The Daily Claw — Curating edition for $DATE (v3 pipeline)"
echo ""

# ============================================
# STEP 1: Verify raw data exists
# ============================================

echo "📡 Step 1: Checking raw data from scrape_v3.py..."
RAW_COUNT=$(ls -1 "$RAW_DIR"/*.json 2>/dev/null | wc -l | tr -d ' ')
if [ "$RAW_COUNT" -lt 5 ]; then
    echo "  ❌ Only $RAW_COUNT files in $RAW_DIR. Run scrape_v3.py first!"
    exit 1
fi

# Check meta freshness
META_DATE=$(jq -r '.date // empty' "$RAW_DIR/meta.json" 2>/dev/null || echo "")
if [ "$META_DATE" != "$DATE" ]; then
    echo "  ⚠️  Raw data is from $META_DATE, not today ($DATE). Run scrape_v3.py to refresh."
    echo "  Continuing with stale data..."
fi

echo "  ✅ $RAW_COUNT raw files found (scraped: ${META_DATE:-unknown})"
echo ""

# ============================================
# STEP 2: Determine edition number
# ============================================

LAST_EDITION=$(ls -1 "$EDITIONS_DIR"/2*.json 2>/dev/null | grep -v latest | grep -v template | sort | tail -1)
if [ -n "$LAST_EDITION" ]; then
    LAST_NUM=$(jq -r '.edition' "$LAST_EDITION" 2>/dev/null || echo "0")
    EDITION=$((LAST_NUM + 1))
else
    EDITION=1
fi

echo "📝 Step 2: Building edition #$EDITION"
echo ""

# ============================================
# STEP 3: Collect & truncate raw data for prompt
# ============================================

echo "🤖 Step 3: AI-assisted curation..."

# Build a focused data summary (keep under 40K chars for Claude)
RAW_SUMMARY=""

# ClawHub
RAW_SUMMARY+="=== CLAWHUB TOP SKILLS ===
$(jq -c '.[:10]' "$RAW_DIR/clawhub-top.json" 2>/dev/null | head -c 3000)

=== CLAWHUB NEW SKILLS ===
$(jq -c '.[:8]' "$RAW_DIR/clawhub-new.json" 2>/dev/null | head -c 2000)

=== CLAWHUB STATS ===
$(cat "$RAW_DIR/clawhub-stats.json" 2>/dev/null | head -c 500)

"

# Models
RAW_SUMMARY+="=== HUGGINGFACE TRENDING ===
$(cat "$RAW_DIR/hf-trending.json" 2>/dev/null | head -c 2000)

=== OPENCLAW RELEASES ===
$(cat "$RAW_DIR/openclaw-releases.json" 2>/dev/null | head -c 1000)

"

# News
RAW_SUMMARY+="=== NEWS HEADLINES (CoinDesk, Decrypt, TheBlock, ArsTechnica) ===
$(jq -c '.[:20]' "$RAW_DIR/news-headlines.json" 2>/dev/null | head -c 5000)

"

# Layer 2
RAW_SUMMARY+="=== REDDIT (r/OpenClaw, r/LocalLLaMA, r/MachineLearning) ===
$(jq -c '.[:15]' "$RAW_DIR/reddit.json" 2>/dev/null | head -c 4000)

=== HACKER NEWS (AI-filtered) ===
$(cat "$RAW_DIR/hackernews.json" 2>/dev/null | head -c 2000)

=== GITHUB TRENDING (AI repos) ===
$(cat "$RAW_DIR/github-trending.json" 2>/dev/null | head -c 3000)

=== SECURITY NEWS ===
$(cat "$RAW_DIR/security.json" 2>/dev/null | head -c 2000)

"

# Layer 3: X
RAW_SUMMARY+="=== X/TWITTER SEARCH (AI agent, OpenClaw, DFDV solana) ===
$(jq -c '.[:20]' "$RAW_DIR/x-search.json" 2>/dev/null | head -c 5000)

=== X PROFILES ===
$(cat "$RAW_DIR/x-profiles.json" 2>/dev/null | head -c 2000)
"

# Truncate to 40K
RAW_SUMMARY="${RAW_SUMMARY:0:40000}"

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
    echo "  ❌ ANTHROPIC_API_KEY not set!"
    exit 1
fi

# Next edition date
NEXT_DATE=$(date -v+1d -j -f "%Y-%m-%d" "$DATE" +%Y-%m-%d 2>/dev/null || date -d "$DATE + 1 day" +%Y-%m-%d 2>/dev/null || echo "")

PROMPT="You are curating The Daily Claw, a daily intelligence brief for AI agent owners and builders. This is edition #$EDITION for $DATE.

Based on the following raw data scraped today from multiple sources, create a curated JSON edition. Pick the MOST interesting, actionable, and relevant items. Prioritize:
- New or trending ClawHub skills
- Model releases or significant updates
- Security alerts affecting AI agents
- Community builds and creative agent use cases
- Significant news from crypto/AI intersection
- Interesting Reddit/HN discussions about agents
- Notable X/Twitter conversations about AI agents

IMPORTANT: Every item must be from TODAY's data. Do not fabricate or hallucinate items.

Raw data from today ($DATE):
$RAW_SUMMARY

Output ONLY valid JSON matching this schema:
{
  \"version\": \"1.0\",
  \"date\": \"$DATE\",
  \"edition\": $EDITION,
  \"published_at\": \"${DATE}T20:00:00Z\",
  \"sections\": {
    \"trending_skills\": [{\"name\": \"\", \"category\": \"\", \"description\": \"\", \"install\": \"\", \"why_trending\": \"\", \"safety\": \"vetted|unvetted\"}],
    \"ai_news\": [{\"headline\": \"\", \"category\": \"\", \"detail\": \"\", \"source_url\": \"\", \"source\": \"\", \"takeaway\": \"\"}],
    \"prompt_hack\": {\"title\": \"\", \"category\": \"\", \"steps\": [], \"why_it_matters\": \"\", \"time_to_implement\": \"\"},
    \"model_radar\": [{\"model\": \"\", \"category\": \"\", \"detail\": \"\", \"relevance\": \"\"}],
    \"community_build\": {\"title\": \"\", \"category\": \"\", \"description\": \"\", \"how_to_replicate\": \"\", \"source\": \"\"},
    \"x_pulse\": [{\"handle\": \"\", \"text\": \"\", \"likes\": 0, \"query\": \"\", \"why_notable\": \"\"}],
    \"security_corner\": [{\"title\": \"\", \"detail\": \"\", \"severity\": \"info|low|medium|high|critical\", \"source_url\": \"\"}]
  },
  \"meta\": {\"version\": \"1.0\", \"source\": \"OpenSource Media\", \"data_sources\": [\"clawhub\", \"huggingface\", \"reddit\", \"hackernews\", \"github\", \"x_search\", \"coindesk\", \"decrypt\", \"theblock\", \"arstechnica\", \"bleepingcomputer\"], \"footer\": \"🦞 The Daily Claw by OSM — clawhub install osm/daily-claw\", \"next_edition\": \"$NEXT_DATE\"}
}"

echo "  → Calling Claude for curation..."

# Write prompt to temp file to avoid shell escaping issues
PROMPT_FILE=$(mktemp)
echo "$PROMPT" > "$PROMPT_FILE"

curl -s https://api.anthropic.com/v1/messages \
    -H "Content-Type: application/json" \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -d "$(jq -n --rawfile prompt "$PROMPT_FILE" '{model: "claude-sonnet-4-6", max_tokens: 8192, messages: [{role: "user", content: $prompt}]}')" \
    | jq -r '.content[0].text' > "$EDITIONS_DIR/$DATE.json"

rm -f "$PROMPT_FILE"

echo "  ✅ AI curation complete"
echo ""

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
    git add editions/ scripts/
    git -c user.name="OpenSource Media" -c user.email="jc@opensourcemedia.xyz" \
        commit -m "🦞 Edition #$EDITION — $DATE (v3 pipeline)" 2>/dev/null || true
    git push origin main 2>/dev/null || echo "  ⚠️  Push failed (run manually)"
    
    echo ""
    echo "🦞 Edition #$EDITION published for $DATE"
    echo "   Feed: https://raw.githubusercontent.com/OpenSourcemediaxyz/daily-claw/main/editions/latest.json"
    echo "   Raw:  $EDITIONS_DIR/$DATE.json"
else
    echo "  ❌ Invalid JSON! Check $EDITIONS_DIR/$DATE.json"
    cat "$EDITIONS_DIR/$DATE.json" | head -20
    exit 1
fi
