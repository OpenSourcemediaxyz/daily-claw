#!/usr/bin/env python3
"""
Daily Claw — Scraper v3 (Scrapling-powered)
Replaces scrape.sh with richer sources, Cloudflare bypass, zero API dependencies.

Layer 1: Replace fragile API sources
Layer 2: Add previously inaccessible sources (Reddit, HN, GitHub trending)
Layer 3: Authenticated X search (when cookies available)

Output: JSON files in /tmp/daily-claw-raw/ (same format as v1)
"""

import json, time, re, os, sys
from datetime import datetime, timezone
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

# Add Scrapling to path
sys.path.insert(0, os.path.expanduser('~/Library/Python/3.9/lib/python/site-packages'))

from scrapling.fetchers import Fetcher, StealthyFetcher

RAW_DIR = Path("/tmp/daily-claw-raw")
RAW_DIR.mkdir(exist_ok=True)

DATE = datetime.now().strftime("%Y-%m-%d")

def save(name, data):
    (RAW_DIR / f"{name}.json").write_text(json.dumps(data, indent=2, default=str))
    print(f"  ✅ {name}.json ({len(json.dumps(data))} bytes)")

# ============================================================
# LAYER 1: Core sources (replacements for curl + API)
# ============================================================

def scrape_clawhub_api():
    """ClawHub API — keep as-is, it works great"""
    print("[L1] ClawHub API...")
    results = {}
    for endpoint, key in [
        ("top-downloads?limit=20", "clawhub-top"),
        ("newest?limit=15", "clawhub-new"),
        ("stats", "clawhub-stats"),
        ("deleted?limit=10", "clawhub-deleted"),
    ]:
        try:
            page = Fetcher.get(f"https://topclawhubskills.com/api/{endpoint}")
            data = json.loads(page.html_content)
            results[key] = data.get('data', data)
        except Exception as e:
            results[key] = {"error": str(e)}
    return results

def scrape_huggingface():
    """HuggingFace trending models via API"""
    print("[L1] HuggingFace trending...")
    try:
        page = Fetcher.get("https://huggingface.co/api/models?sort=likes7d&direction=-1&limit=15")
        models = json.loads(page.html_content)
        return [{"modelId": m["modelId"], "likes": m.get("likes",0), "downloads": m.get("downloads",0), "pipeline_tag": m.get("pipeline_tag","")} for m in models]
    except Exception as e:
        return {"error": str(e)}

def scrape_openclaw_releases():
    """OpenClaw GitHub releases"""
    print("[L1] OpenClaw releases...")
    try:
        page = Fetcher.get("https://api.github.com/repos/openclaw/openclaw/releases?per_page=3")
        releases = json.loads(page.html_content)
        return [{"tag_name": r["tag_name"], "name": r["name"], "published_at": r["published_at"]} for r in releases]
    except Exception as e:
        return {"error": str(e)}

def scrape_news_sites():
    """Direct scrape of crypto/AI news sites (replaces Brave Search)"""
    print("[L1] News sites (CoinDesk, Decrypt, TheBlock)...")
    headlines = []
    
    sites = [
        ("https://www.coindesk.com", "CoinDesk"),
        ("https://decrypt.co", "Decrypt"),
        ("https://www.theblock.co", "TheBlock"),
        ("https://arstechnica.com/ai/", "ArsTechnica"),
    ]
    
    for url, source in sites:
        try:
            page = StealthyFetcher.fetch(url, headless=True, network_idle=False, timeout=15000)
            # Extract all links with text
            links = page.css('a')
            for a in links:
                text = (a.text or "").strip()
                href = a.attrib.get('href', '')
                if text and 25 < len(text) < 150 and any(k in href for k in ['article', '202', '/ai/', '/tech/', '/policy/', '/business/']):
                    headlines.append({
                        "title": text[:150],
                        "url": href if href.startswith('http') else f"{url.rstrip('/')}{href}",
                        "source": source
                    })
        except Exception as e:
            headlines.append({"error": str(e), "source": source})
    
    # Deduplicate by title
    seen = set()
    unique = []
    for h in headlines:
        title = h.get('title', '')
        if title and title not in seen:
            seen.add(title)
            unique.append(h)
    
    return unique[:30]

# ============================================================
# LAYER 2: New sources (previously inaccessible)
# ============================================================

def scrape_reddit():
    """Reddit r/OpenClaw + r/LocalLLaMA — community builds, prompt hacks"""
    print("[L2] Reddit...")
    posts = []
    subreddits = ["OpenClaw", "LocalLLaMA", "MachineLearning"]
    
    for sub in subreddits:
        try:
            # Reddit's .json endpoint works without auth
            page = Fetcher.get(f"https://www.reddit.com/r/{sub}/hot.json?limit=10", 
                             stealthy_headers=True)
            data = json.loads(page.html_content)
            for child in data.get('data', {}).get('children', []):
                post = child.get('data', {})
                if post.get('score', 0) > 10:  # Filter low-quality
                    posts.append({
                        "title": post.get('title', '')[:150],
                        "subreddit": sub,
                        "score": post.get('score', 0),
                        "comments": post.get('num_comments', 0),
                        "url": f"https://reddit.com{post.get('permalink', '')}",
                        "created": post.get('created_utc', 0)
                    })
        except Exception as e:
            posts.append({"error": str(e), "subreddit": sub})
    
    # Sort by score
    posts.sort(key=lambda x: x.get('score', 0), reverse=True)
    return posts[:20]

def scrape_hackernews():
    """Hacker News — AI/agent related posts"""
    print("[L2] Hacker News...")
    try:
        # Get top stories
        page = Fetcher.get("https://hacker-news.firebaseio.com/v0/topstories.json")
        story_ids = json.loads(page.html_content)[:30]
        
        stories = []
        for sid in story_ids[:30]:
            try:
                sp = Fetcher.get(f"https://hacker-news.firebaseio.com/v0/item/{sid}.json")
                story = json.loads(sp.html_content)
                title = story.get('title', '').lower()
                # Filter for AI/agent relevance
                if any(k in title for k in ['ai', 'agent', 'llm', 'model', 'openclaw', 'claude', 'gpt', 'anthropic', 'openai', 'scraping', 'automation']):
                    stories.append({
                        "title": story.get('title', ''),
                        "url": story.get('url', f"https://news.ycombinator.com/item?id={sid}"),
                        "score": story.get('score', 0),
                        "comments": story.get('descendants', 0),
                        "hn_url": f"https://news.ycombinator.com/item?id={sid}"
                    })
            except:
                continue
        
        stories.sort(key=lambda x: x.get('score', 0), reverse=True)
        return stories[:10]
    except Exception as e:
        return {"error": str(e)}

def scrape_github_trending():
    """GitHub trending repos — AI/agents/LLM"""
    print("[L2] GitHub trending...")
    try:
        page = StealthyFetcher.fetch("https://github.com/trending?since=daily&spoken_language_code=en", 
                                      headless=True, timeout=15000)
        repos = []
        articles = page.css('article')
        for art in articles[:20]:
            # Extract repo name
            h2 = art.css('h2 a')
            if h2:
                href = h2[0].attrib.get('href', '')
                name = href.strip('/')
                
                # Extract description
                p = art.css('p')
                desc = (p[0].text or "").strip() if p else ""
                
                # Extract stars today
                stars_text = ""
                spans = art.css('span')
                for s in spans:
                    t = (s.text or "").strip()
                    if 'stars today' in t:
                        stars_text = t
                        break
                
                # Filter for AI relevance
                combined = f"{name} {desc}".lower()
                if any(k in combined for k in ['ai', 'agent', 'llm', 'model', 'openclaw', 'gpt', 'claude', 'ml', 'neural', 'transformer', 'scraping']):
                    repos.append({
                        "name": name,
                        "description": desc[:200],
                        "url": f"https://github.com{href}",
                        "stars_today": stars_text
                    })
        
        return repos[:10]
    except Exception as e:
        return {"error": str(e)}

def scrape_security():
    """Security news — AI/agent vulnerabilities"""
    print("[L2] Security news...")
    try:
        page = StealthyFetcher.fetch("https://www.bleepingcomputer.com/", headless=True, timeout=15000)
        articles = []
        links = page.css('a')
        for a in links:
            text = (a.text or "").strip()
            href = a.attrib.get('href', '')
            if text and 25 < len(text) < 150 and '/news/' in href:
                title_lower = text.lower()
                if any(k in title_lower for k in ['ai', 'agent', 'llm', 'vulnerability', 'security', 'hack', 'breach', 'malware', 'chrome', 'api']):
                    articles.append({
                        "title": text[:150],
                        "url": href if href.startswith('http') else f"https://www.bleepingcomputer.com{href}",
                        "source": "BleepingComputer"
                    })
        return articles[:10]
    except Exception as e:
        return {"error": str(e)}

# ============================================================
# LAYER 3: Authenticated X search
# ============================================================

def scrape_x_profiles():
    """Scrape key X profiles for AI/agent tweets (no auth needed)"""
    print("[L3-lite] X profiles (no auth)...")
    profiles = [
        "OpenClawCode", "AnthropicAI", "xaborathinly", "kaborathinly",
        "steipete", "halthelobster", "elaboratenews"
    ]
    
    tweets = []
    for handle in profiles:
        try:
            page = StealthyFetcher.fetch(f"https://x.com/{handle}", headless=True, network_idle=True, timeout=15000)
            # Extract tweet text from HTML
            tweet_texts = re.findall(r'data-testid="tweetText"[^>]*>(.*?)</div', page.html_content, re.DOTALL)
            if not tweet_texts:
                # Fallback: extract from raw text content
                matches = re.findall(r'"full_text":"(.*?)"', page.html_content)
                for m in matches[:3]:
                    text = m.encode().decode('unicode_escape', errors='ignore')
                    if len(text) > 20:
                        tweets.append({"handle": handle, "text": text[:280], "source": "profile_scrape"})
        except:
            continue
    
    return tweets[:15]

def scrape_x_search_authenticated():
    """Authenticated X search via PlayWright (Chromium) + cookie injection + network interception.
    IMPORTANT: Must use PlayWrightFetcher, NOT StealthyFetcher (Camoufox).
    X's GraphQL API blocks Camoufox but allows real Chromium."""
    print("[L3] X authenticated search (Chromium)...")
    
    from scrapling.fetchers import PlayWrightFetcher
    
    # Load cookies from env
    auth_token = os.environ.get('X_AUTH_TOKEN', '')
    ct0_token = os.environ.get('X_CT0', '')
    
    if not auth_token or not ct0_token:
        return {"error": "X cookies not configured", "hint": "Set X_AUTH_TOKEN and X_CT0 env vars"}
    
    queries = ["AI agent", "OpenClaw", "DFDV solana"]
    all_tweets = []
    
    for query in queries:
        try:
            captured = []
            
            def capture_search(page, _q=query, _cap=captured):
                page.context.add_cookies([
                    {'name': 'auth_token', 'value': auth_token, 'domain': '.x.com', 'path': '/', 'httpOnly': True, 'secure': True},
                    {'name': 'ct0', 'value': ct0_token, 'domain': '.x.com', 'path': '/', 'secure': True},
                ])
                
                def on_response(response):
                    if 'SearchTimeline' in response.url and response.status == 200:
                        try:
                            body = response.body()
                            if body and len(body) > 200:
                                _cap.append(json.loads(body))
                        except:
                            pass
                
                page.on('response', on_response)
                
                import urllib.parse
                encoded = urllib.parse.quote(_q)
                page.goto(f'https://x.com/search?q={encoded}&src=typed_query&f=live', timeout=20000)
                page.wait_for_timeout(8000)
                return page
            
            PlayWrightFetcher.fetch('https://x.com', headless=True,
                                    page_action=capture_search, timeout=30000)
            
            # Parse captured GraphQL responses
            for data in captured:
                try:
                    instructions = data['data']['search_by_raw_query']['search_timeline']['timeline']['instructions']
                    for inst in instructions:
                        for entry in inst.get('entries', []):
                            try:
                                result = entry['content']['itemContent']['tweet_results']['result']
                                # Handle both direct and nested tweet objects
                                legacy = result.get('legacy') or result.get('tweet',{}).get('legacy',{})
                                core = result.get('core') or result.get('tweet',{}).get('core',{})
                                user_legacy = core.get('user_results',{}).get('result',{}).get('legacy',{})
                                
                                all_tweets.append({
                                    "query": query,
                                    "handle": user_legacy.get('screen_name', '?'),
                                    "name": user_legacy.get('name', '?'),
                                    "text": legacy.get('full_text', '')[:280],
                                    "likes": legacy.get('favorite_count', 0),
                                    "retweets": legacy.get('retweet_count', 0),
                                    "created": legacy.get('created_at', ''),
                                    "followers": user_legacy.get('followers_count', 0),
                                })
                            except:
                                continue
                except:
                    continue
        except Exception as e:
            all_tweets.append({"error": str(e), "query": query})
    
    all_tweets.sort(key=lambda x: x.get('likes', 0), reverse=True)
    return all_tweets[:30]


# ============================================================
# MAIN
# ============================================================

def main():
    print(f"🦞 Daily Claw Scraper v3 — {DATE}")
    print(f"Output: {RAW_DIR}/\n")
    
    t0 = time.time()
    
    # Layer 1: Core sources
    print("=== LAYER 1: Core Sources ===")
    clawhub = scrape_clawhub_api()
    for key, data in clawhub.items():
        save(key, data)
    
    save("hf-trending", scrape_huggingface())
    save("openclaw-releases", scrape_openclaw_releases())
    save("news-headlines", scrape_news_sites())
    
    # Layer 2: New sources
    print("\n=== LAYER 2: New Sources ===")
    save("reddit", scrape_reddit())
    save("hackernews", scrape_hackernews())
    save("github-trending", scrape_github_trending())
    save("security", scrape_security())
    
    # Layer 3: X/Twitter
    print("\n=== LAYER 3: X/Twitter ===")
    save("x-profiles", scrape_x_profiles())
    
    auth_token = os.environ.get('X_AUTH_TOKEN', '')
    if auth_token:
        save("x-search", scrape_x_search_authenticated())
    else:
        print("  ⏭️  X auth not configured, skipping authenticated search")
    
    # Metadata
    save("meta", {
        "scraped_at": datetime.now(timezone.utc).isoformat(),
        "date": DATE,
        "version": "v3",
        "layers": ["core", "expanded", "x_auth" if auth_token else "x_profiles_only"]
    })
    
    t1 = time.time()
    print(f"\n✅ Scrape complete in {t1-t0:.1f}s")
    print(f"Files: {len(list(RAW_DIR.glob('*.json')))}")

if __name__ == "__main__":
    main()
