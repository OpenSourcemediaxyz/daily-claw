#!/bin/bash
# The Daily Claw — Automated Curation Pipeline v2
# Runs daily via cron at 7 AM CST
#
# Usage: ./scripts/curate-v2.sh [date]
# Requires: curl, jq, git

set -euo pipefail

DATE="${1:-$(date +%Y-%m-%d)}"
NEXT_DATE="$(date -v+1d -j -f "%Y-%m-%d" "$DATE" +%Y-%m-%d 2>/dev/null || date -d "$DATE + 1 day" +%Y-%m-%d)"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EDITIONS_DIR="$REPO_ROOT/editions"
RAW_DIR="/tmp/daily-claw-raw"

mkdir -p "$EDITIONS_DIR" "$RAW_DIR"

echo "🦞 The Daily Claw — Curating edition for $DATE"
echo "================================================"
echo ""

# ============================================
# STEP 1: Scrape all sources
# ============================================

echo "📡 Step 1: Scraping sources..."

# 1a. ClawhHub — Top downloads (velocity = trending)
echo "  → ClawhHub top downloads..."
curl -s "https://topclawhubskills.com/api/top-downloads?limit=20" | jq '.data' > "$RAW_DIR/clawhub-top.json" 2>/dev/null || echo "[]" > "$RAW_DIR/clawhub-top.json"

# 1b. ClawhHub — Newest skills
echo "  → ClawhHub newest skills..."
curl -s "https://topclawhubskills.com/api/newest?limit=15" | jq '.data' > "$RAW_DIR/clawhub-new.json" 2>/dev/null || echo "[]" > "$RAW_DIR/clawhub-new.json"

# 1c. ClawhHub — Platform stats
echo "  → ClawhHub stats..."
curl -s "https://topclawhubskills.com/api/stats" | jq '.data' > "$RAW_DIR/clawhub-stats.json" 2>/dev/null || echo "{}" > "$RAW_DIR/clawhub-stats.json"

# 1d. ClawhHub — Deleted/suspicious skills (security signal)
echo "  → ClawhHub deleted skills..."
curl -s "https://topclawhubskills.com/api/deleted?limit=10" | jq '.data' > "$RAW_DIR/clawhub-deleted.json" 2>/dev/null || echo "[]" > "$RAW_DIR/clawhub-deleted.json"

# 2. HuggingFace — Trending models (by weekly likes)
echo "  → HuggingFace trending models..."
curl -s "https://huggingface.co/api/models?sort=likes7d&direction=-1&limit=10" | jq '[.[] | {modelId, likes, downloads, pipeline_tag, lastModified}]' > "$RAW_DIR/hf-trending.json" 2>/dev/null || echo "[]" > "$RAW_DIR/hf-trending.json"

# 3. OpenClaw GitHub — Latest releases
echo "  → OpenClaw releases..."
curl -s "https://api.github.com/repos/openclaw/openclaw/releases?per_page=3" | jq '[.[] | {tag_name, name, published_at, body: (.body | split("\n") | .[0:20] | join("\n"))}]' > "$RAW_DIR/openclaw-releases.json" 2>/dev/null || echo "[]" > "$RAW_DIR/openclaw-releases.json"

# 4. Hacker News — Top stories (we'll filter for AI/agent relevance)
echo "  → Hacker News top stories..."
HN_IDS=$(curl -s "https://hacker-news.firebaseio.com/v0/topstories.json" | jq '.[0:30]' 2>/dev/null || echo "[]")
HN_ITEMS="[]"
if [ "$HN_IDS" != "[]" ]; then
    HN_ITEMS="["
    FIRST=true
    for id in $(echo "$HN_IDS" | jq '.[]' 2>/dev/null | head -30); do
        ITEM=$(curl -s "https://hacker-news.firebaseio.com/v0/item/${id}.json" 2>/dev/null | jq '{title, url, score, by}' 2>/dev/null)
        if [ -n "$ITEM" ] && [ "$ITEM" != "null" ]; then
            TITLE=$(echo "$ITEM" | jq -r '.title' 2>/dev/null)
            # Filter for AI/agent/LLM relevance
            if echo "$TITLE" | grep -iqE "ai |agent|llm|gpt|claude|gemini|model|openclaw|deepseek|anthropic|openai|machine learn"; then
                [ "$FIRST" = true ] && FIRST=false || HN_ITEMS="$HN_ITEMS,"
                HN_ITEMS="$HN_ITEMS $ITEM"
            fi
        fi
    done
    HN_ITEMS="$HN_ITEMS ]"
fi
echo "$HN_ITEMS" | jq '.' > "$RAW_DIR/hn-ai.json" 2>/dev/null || echo "[]" > "$RAW_DIR/hn-ai.json"

# 5. Brave Search — AI agent news
echo "  → Brave Search: AI agent news..."
# Pull from 1Password if not already in env
if [ -z "${BRAVE_API_KEY:-}" ]; then
    BRAVE_API_KEY=$(op read "op://Agent Secrets/Brave API Key/password" 2>/dev/null || echo "")
fi
if [ -n "${BRAVE_API_KEY:-}" ]; then
    curl -s "https://api.search.brave.com/res/v1/web/search?q=AI+agent+news+today&freshness=pd&count=10" \
        -H "Accept: application/json" \
        -H "X-Subscription-Token: $BRAVE_API_KEY" | jq '[.web.results[] | {title, url, description}]' > "$RAW_DIR/brave-news.json" 2>/dev/null || echo "[]" > "$RAW_DIR/brave-news.json"
    
    sleep 1  # Rate limit

    curl -s "https://api.search.brave.com/res/v1/web/search?q=AI+agent+security+vulnerability+CVE&freshness=pw&count=5" \
        -H "Accept: application/json" \
        -H "X-Subscription-Token: $BRAVE_API_KEY" | jq '[.web.results[] | {title, url, description}]' > "$RAW_DIR/brave-security.json" 2>/dev/null || echo "[]" > "$RAW_DIR/brave-security.json"
else
    echo "  ⚠️  No BRAVE_API_KEY — skipping web search"
    echo "[]" > "$RAW_DIR/brave-news.json"
    echo "[]" > "$RAW_DIR/brave-security.json"
fi

echo "  ✅ Scraping complete"
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

echo "📝 Step 2: Generating edition #$EDITION"
echo ""

# ============================================
# STEP 3: Build the prompt + call Claude
# ============================================

# Combine all raw data
CLAWHUB_TOP=$(cat "$RAW_DIR/clawhub-top.json")
CLAWHUB_NEW=$(cat "$RAW_DIR/clawhub-new.json")
CLAWHUB_STATS=$(cat "$RAW_DIR/clawhub-stats.json")
CLAWHUB_DELETED=$(cat "$RAW_DIR/clawhub-deleted.json")
HF_TRENDING=$(cat "$RAW_DIR/hf-trending.json")
OC_RELEASES=$(cat "$RAW_DIR/openclaw-releases.json")
HN_AI=$(cat "$RAW_DIR/hn-ai.json")
BRAVE_NEWS=$(cat "$RAW_DIR/brave-news.json")
BRAVE_SEC=$(cat "$RAW_DIR/brave-security.json")

# Build the prompt
PROMPT=$(cat << 'PROMPT_END'
You are curating The Daily Claw — a daily intelligence brief for AI agent owners (people who run personal AI agents via OpenClaw and similar frameworks).

Today's date: DATE_PLACEHOLDER

## Raw Data From Today's Scrapes:

### ClawhHub Top Downloaded Skills (current leaders):
CLAWHUB_TOP_PLACEHOLDER

### ClawhHub Newest Skills (just published):
CLAWHUB_NEW_PLACEHOLDER

### ClawhHub Platform Stats:
CLAWHUB_STATS_PLACEHOLDER

### ClawhHub Deleted Skills (potential security concern):
CLAWHUB_DELETED_PLACEHOLDER

### HuggingFace Trending Models (by weekly likes):
HF_TRENDING_PLACEHOLDER

### OpenClaw Releases:
OC_RELEASES_PLACEHOLDER

### Hacker News AI Stories:
HN_AI_PLACEHOLDER

### Web Search — AI Agent News:
BRAVE_NEWS_PLACEHOLDER

### Web Search — Security:
BRAVE_SEC_PLACEHOLDER

## Your Task:

Create a Daily Claw edition. Pick the most interesting, actionable, and relevant items from the raw data above. Focus on NEW things — not skills that have been top-downloaded for weeks.

For trending_skills: Prioritize NEWEST skills that are gaining traction fast, or established skills with notable updates. Include install commands (clawhub install owner/skill-name format).

For ai_tweets: Frame real news as if summarizing what the community is discussing. Include source URLs.

For prompt_hack: Create one genuinely useful, copy-paste-ready tip that an agent owner can implement in under 5 minutes.

For model_radar: Focus on new model releases or significant updates. Include practical relevance for agent operators.

For community_build: Highlight a real project or creative use of agents from the data.

## Output Format:

Return ONLY valid JSON (no markdown, no explanation) matching this exact schema:

{"version":"1.0","date":"DATE_PLACEHOLDER","edition":EDITION_PLACEHOLDER,"published_at":"DATE_PLACEHOLDERT14:00:00Z","sections":{"trending_skills":[{"name":"","category":"","description":"","install":"clawhub install owner/name","why_trending":"","safety":"vetted"}],"ai_tweets":[{"headline":"","category":"","detail":"","source_url":"","takeaway":""}],"prompt_hack":{"title":"","category":"","steps":[""],"why_it_matters":"","time_to_implement":""},"model_radar":[{"model":"","category":"","detail":"","relevance":""}],"community_build":{"title":"","category":"","description":"","how_to_replicate":"","source":""}},"meta":{"version":"1.0","source":"OpenSource Media","website":"https://opensourcemedia.xyz","github":"https://github.com/OpenSourcemediaxyz/daily-claw","footer":"🦞 The Daily Claw by OSM — clawhub install osm/daily-claw","next_edition":"NEXT_DATE_PLACEHOLDER"}}

Include 3-5 trending_skills, 3-5 ai_tweets, 1 prompt_hack, 1-3 model_radar items, and 1 community_build. Make every item specific and actionable. No fluff.
PROMPT_END
)

# Replace placeholders
PROMPT="${PROMPT//DATE_PLACEHOLDER/$DATE}"
PROMPT="${PROMPT//NEXT_DATE_PLACEHOLDER/$NEXT_DATE}"
PROMPT="${PROMPT//EDITION_PLACEHOLDER/$EDITION}"
PROMPT="${PROMPT//CLAWHUB_TOP_PLACEHOLDER/$CLAWHUB_TOP}"
PROMPT="${PROMPT//CLAWHUB_NEW_PLACEHOLDER/$CLAWHUB_NEW}"
PROMPT="${PROMPT//CLAWHUB_STATS_PLACEHOLDER/$CLAWHUB_STATS}"
PROMPT="${PROMPT//CLAWHUB_DELETED_PLACEHOLDER/$CLAWHUB_DELETED}"
PROMPT="${PROMPT//HF_TRENDING_PLACEHOLDER/$HF_TRENDING}"
PROMPT="${PROMPT//OC_RELEASES_PLACEHOLDER/$OC_RELEASES}"
PROMPT="${PROMPT//HN_AI_PLACEHOLDER/$HN_AI}"
PROMPT="${PROMPT//BRAVE_NEWS_PLACEHOLDER/$BRAVE_NEWS}"
PROMPT="${PROMPT//BRAVE_SEC_PLACEHOLDER/$BRAVE_SEC}"

echo "🤖 Step 3: AI curation via OpenClaw gateway..."

# Use OpenClaw's gateway to call Claude (it manages the API key)
# Build JSON payload for the Anthropic API via gateway proxy
PAYLOAD=$(jq -n \
    --arg prompt "$PROMPT" \
    '{
        model: "anthropic/claude-sonnet-4-6",
        max_tokens: 4096,
        messages: [{role: "user", content: $prompt}]
    }')

# Call via OpenClaw gateway's provider proxy
RESPONSE=$(curl -s -X POST "http://127.0.0.1:18789/api/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer 3a829a8e17ac23d0a556e2632a070c04a57357523702fd09" \
    -d "$PAYLOAD" 2>/dev/null)

# Extract the content from the response
EDITION_JSON=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // .content[0].text // empty' 2>/dev/null)

if [ -z "$EDITION_JSON" ]; then
    echo "  ⚠️  Gateway call failed. Trying direct summarize approach..."
    # Fallback: use summarize CLI or write raw data edition
    echo "$RESPONSE" | head -c 500
    echo ""
    echo "  ❌ Could not generate edition. Raw data saved in $RAW_DIR"
    exit 1
fi

# Clean any markdown wrapping
EDITION_JSON=$(echo "$EDITION_JSON" | sed 's/^```json//;s/^```//;s/```$//')

echo "  ✅ AI curation complete"
echo ""

# ============================================
# STEP 4: Validate + publish
# ============================================

echo "✅ Step 4: Validating and publishing..."

if echo "$EDITION_JSON" | jq empty 2>/dev/null; then
    echo "  ✅ Valid JSON"
    
    # Save edition
    echo "$EDITION_JSON" | jq '.' > "$EDITIONS_DIR/$DATE.json"
    cp "$EDITIONS_DIR/$DATE.json" "$EDITIONS_DIR/latest.json"
    echo "  ✅ Saved: editions/$DATE.json + latest.json"
    
    # Git commit + push
    cd "$REPO_ROOT"
    git add editions/
    git commit -m "🦞 Edition #$EDITION — $DATE (auto-curated)" 2>/dev/null
    
    if git push origin main 2>/dev/null; then
        echo "  ✅ Pushed to GitHub"
    elif git push osm main 2>/dev/null; then
        echo "  ✅ Pushed to GitHub (osm remote)"
    else
        echo "  ⚠️  Push failed — run manually: cd $REPO_ROOT && git push"
    fi
    
    echo ""
    echo "🦞 Edition #$EDITION published for $DATE"
    echo "   Feed: https://raw.githubusercontent.com/OpenSourcemediaxyz/daily-claw/main/editions/latest.json"
else
    echo "  ❌ Invalid JSON! Saving raw output for debugging..."
    echo "$EDITION_JSON" > "$RAW_DIR/failed-$DATE.json"
    echo "  Debug: $RAW_DIR/failed-$DATE.json"
    exit 1
fi
