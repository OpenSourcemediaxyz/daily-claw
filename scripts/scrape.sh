#!/bin/bash
# Daily Claw — Data Scraper
# Collects raw data from all sources. AI curation done separately.
# Run via cron at 6:30 AM CST daily.

set -euo pipefail

RAW_DIR="/tmp/daily-claw-raw"
mkdir -p "$RAW_DIR"

DATE=$(date +%Y-%m-%d)
echo "🦞 Scraping data for $DATE..."

# 1. ClawhHub
curl -s "https://topclawhubskills.com/api/top-downloads?limit=20" | jq '.data' > "$RAW_DIR/clawhub-top.json" 2>/dev/null &
curl -s "https://topclawhubskills.com/api/newest?limit=15" | jq '.data' > "$RAW_DIR/clawhub-new.json" 2>/dev/null &
curl -s "https://topclawhubskills.com/api/stats" | jq '.data' > "$RAW_DIR/clawhub-stats.json" 2>/dev/null &
curl -s "https://topclawhubskills.com/api/deleted?limit=10" | jq '.data' > "$RAW_DIR/clawhub-deleted.json" 2>/dev/null &

# 2. HuggingFace
curl -s "https://huggingface.co/api/models?sort=likes7d&direction=-1&limit=10" | jq '[.[] | {modelId, likes, downloads, pipeline_tag}]' > "$RAW_DIR/hf-trending.json" 2>/dev/null &

# 3. OpenClaw releases
curl -s "https://api.github.com/repos/openclaw/openclaw/releases?per_page=3" | jq '[.[] | {tag_name, name, published_at}]' > "$RAW_DIR/openclaw-releases.json" 2>/dev/null &

# Wait for all parallel fetches
wait

# 4. Brave Search (sequential — rate limited)
# Pull from 1Password if not already in env
if [ -z "${BRAVE_API_KEY:-}" ]; then
    BRAVE_API_KEY=$(op read "op://Agent Secrets/Brave API Key/password" 2>/dev/null || echo "")
fi
if [ -n "${BRAVE_API_KEY:-}" ]; then
    curl -s "https://api.search.brave.com/res/v1/web/search?q=AI+agent+news+today+OpenClaw&freshness=pd&count=10" \
        -H "Accept: application/json" \
        -H "X-Subscription-Token: $BRAVE_API_KEY" | jq '[.web.results[:8] | .[] | {title, url, description: (.description[0:200])}]' > "$RAW_DIR/brave-news.json" 2>/dev/null
    sleep 1
    curl -s "https://api.search.brave.com/res/v1/web/search?q=AI+agent+security+vulnerability+2026&freshness=pw&count=5" \
        -H "Accept: application/json" \
        -H "X-Subscription-Token: $BRAVE_API_KEY" | jq '[.web.results[:5] | .[] | {title, url, description: (.description[0:200])}]' > "$RAW_DIR/brave-security.json" 2>/dev/null
fi

# Timestamp
echo "{\"scraped_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"date\": \"$DATE\"}" > "$RAW_DIR/meta.json"

echo "✅ Scraping complete. Data in $RAW_DIR/"
ls -la "$RAW_DIR/"
