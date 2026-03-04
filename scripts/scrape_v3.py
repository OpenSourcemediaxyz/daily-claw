#!/usr/bin/env python3
"""
Daily Claw — Scraper v3 (Scrapling-powered)
Replaces scrape.sh with richer sources, Cloudflare bypass, zero API dependencies.

Layer 1: Replace fragile API sources
Layer 2: Add previously inaccessible sources (Reddit, HN, GitHub trending)
Layer 3: Authenticated X search (when cookies available)

Output: JSON files in /tmp/daily-claw-raw/ (same format as v1)

TECHNICAL NOTES:
- Fetcher.get().text returns raw response body (use for JSON APIs)
- Fetcher.get().html_content wraps in <html><body> (use for HTML pages)
- X GraphQL API blocks Camoufox (StealthyFetcher) — MUST use PlayWrightFetcher
- StealthyFetcher works great for CF-protected HTML sites (CoinDesk, Decrypt, etc.)
"""

import json, time, re, os, sys
from datetime import datetime, timezone
from pathlib import Path

# Add Scrapling to path
sys.path.insert(0, os.path.expanduser('~/Library/Python/3.9/lib/python/site-packages'))

from scrapling.fetchers import Fetcher, StealthyFetcher

RAW_DIR = Path("/tmp/daily-claw-raw")
RAW_DIR.mkdir(exist_ok=True)

DATE = datetime.now().strftime("%Y-%m-%d")

def save(name, data):
    out = json.dumps(data, indent=2, default=str)
    (RAW_DIR / f"{name}.json").write_text(out)
    count = len(data) if isinstance(data, list) else ("error" if "error" in data else "obj")
    print(f"  ✅ {name}.json ({len(out)} bytes, {count})")

def fetch_json(url):
    """Fetch a JSON API endpoint — uses .text to avoid HTML wrapping"""
    page = Fetcher.get(url)
    return json.loads(page.text)

# ============================================================
# LAYER 1: Core sources (replacements for curl + API)
# ============================================================

def scrape_clawhub_api():
    """ClawHub API — lightweight JSON fetches"""
    print("[L1] ClawHub API...")
    results = {}
    for endpoint, key in [
        ("top-downloads?limit=20", "clawhub-top"),
        ("newest?limit=15", "clawhub-new"),
        ("stats", "clawhub-stats"),
        ("deleted?limit=10", "clawhub-deleted"),
    ]:
        try:
            data = fetch_json(f"https://topclawhubskills.com/api/{endpoint}")
            results[key] = data.get('data', data)
        except Exception as e:
            results[key] = {"error": str(e)}
    return results

def scrape_huggingface():
    """HuggingFace trending models via API"""
    print("[L1] HuggingFace trending...")
    try:
        models = fetch_json("https://huggingface.co/api/models?sort=likes7d&direction=-1&limit=15")
        return [{"modelId": m["modelId"], "likes": m.get("likes",0), "downloads": m.get("downloads",0), "pipeline_tag": m.get("pipeline_tag","")} for m in models]
    except Exception as e:
        return {"error": str(e)}

def scrape_openclaw_releases():
    """OpenClaw GitHub releases"""
    print("[L1] OpenClaw releases...")
    try:
        releases = fetch_json("https://api.github.com/repos/openclaw/openclaw/releases?per_page=3")
        return [{"tag_name": r["tag_name"], "name": r["name"], "published_at": r["published_at"]} for r in releases]
    except Exception as e:
        return {"error": str(e)}

def scrape_news_sites():
    """Scrape crypto/AI news — hybrid approach: HTML scrape for CoinDesk, RSS for others"""
    print("[L1] News sites...")
    headlines = []
    
    # CoinDesk: HTML scrape (best headlines, works with StealthyFetcher)
    try:
        page = StealthyFetcher.fetch("https://www.coindesk.com", headless=True, network_idle=False, timeout=15000)
        links = page.css('a')
        count = 0
        href_patterns = ['article', '/202', '/markets/', '/tech/', '/policy/', '/business/', '/consensus']
        for a in links:
            href = a.attrib.get('href', '')
            if not any(k in href for k in href_patterns):
                continue
            inner = a.html_content if hasattr(a, 'html_content') else (a.text or '')
            text = re.sub(r'<[^>]+>', ' ', inner).strip() if '<' in inner else inner.strip()
            text = re.sub(r'\s+', ' ', text).strip()
            if not text or len(text) < 25 or len(text) > 200:
                continue
            if any(skip in text.lower() for skip in ['sign up', 'log in', 'subscribe', 'newsletter', 'cookie', 'privacy', 'read more']):
                continue
            full_url = href if href.startswith('http') else f"https://www.coindesk.com{href}"
            headlines.append({"title": text[:200], "url": full_url, "source": "CoinDesk"})
            count += 1
        print(f"    CoinDesk: {count} headlines (HTML)")
    except Exception as e:
        print(f"    CoinDesk: ERROR — {e}")
    
    # RSS feeds for Decrypt, TheBlock, ArsTechnica
    rss_feeds = [
        ("https://decrypt.co/feed", "Decrypt"),
        ("https://www.theblock.co/rss.xml", "TheBlock"),
        ("https://feeds.arstechnica.com/arstechnica/technology-lab", "ArsTechnica"),
    ]
    
    for feed_url, source in rss_feeds:
        try:
            page = Fetcher.get(feed_url)
            xml = page.html_content  # RSS wrapped in <html><body> by Scrapling
            items = re.findall(r'<item>(.*?)</item>', xml, re.DOTALL)
            count = 0
            for item in items[:15]:
                # Title: plain text, no CDATA on these feeds
                title = re.search(r'<title[^>]*>(.*?)</title>', item, re.DOTALL)
                # Link: can be <link>URL</link> or after self-closing <link/>
                # <link> may have no closing tag — grab URL up to next tag or whitespace+tag
                link = re.search(r'<link[^>]*>\s*(https?://[^\s<]+)', item)
                if not link:
                    # Atom-style: <link href="URL"/>
                    link = re.search(r'<link[^>]+href="([^"]+)"', item)
                if not link:
                    # Some feeds use <guid> as link
                    link = re.search(r'<guid[^>]*ispermalink="true"[^>]*>(https?://[^\s<]+)', item, re.IGNORECASE)
                if title and link:
                    t = re.sub(r'<[^>]+>', '', title.group(1)).strip()
                    # Unescape HTML entities
                    t = t.replace('&#39;', "'").replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>').replace('&quot;', '"')
                    # Strip whitespace/newlines from URL (Scrapling HTML parser may insert them)
                    u = re.sub(r'\s+', '', link.group(1))
                    if t and len(t) > 15 and u.startswith('http'):
                        headlines.append({"title": t[:200], "url": u, "source": source})
                        count += 1
            print(f"    {source}: {count} headlines (RSS)")
        except Exception as e:
            print(f"    {source}: ERROR — {e}")
    
    # Deduplicate by title
    seen = set()
    unique = []
    for h in headlines:
        title = h.get('title', '')
        if title and title not in seen:
            seen.add(title)
            unique.append(h)
    
    return unique[:50]

# ============================================================
# LAYER 2: New sources (previously inaccessible)
# ============================================================

def scrape_reddit():
    """Reddit AI/agent subreddits"""
    print("[L2] Reddit...")
    posts = []
    subreddits = ["OpenClaw", "LocalLLaMA", "MachineLearning"]
    
    for sub in subreddits:
        try:
            data = fetch_json(f"https://www.reddit.com/r/{sub}/hot.json?limit=10")
            count = 0
            for child in data.get('data', {}).get('children', []):
                post = child.get('data', {})
                if post.get('score', 0) > 5:
                    posts.append({
                        "title": post.get('title', '')[:150],
                        "subreddit": sub,
                        "score": post.get('score', 0),
                        "comments": post.get('num_comments', 0),
                        "url": f"https://reddit.com{post.get('permalink', '')}",
                        "created": post.get('created_utc', 0)
                    })
                    count += 1
            print(f"    r/{sub}: {count} posts")
        except Exception as e:
            print(f"    r/{sub}: ERROR — {e}")
    
    posts.sort(key=lambda x: x.get('score', 0), reverse=True)
    return posts[:20]

def scrape_hackernews():
    """Hacker News — AI/agent related posts"""
    print("[L2] Hacker News...")
    try:
        story_ids = fetch_json("https://hacker-news.firebaseio.com/v0/topstories.json")[:40]
        
        stories = []
        keywords = ['ai', 'agent', 'llm', 'model', 'openclaw', 'claude', 'gpt', 'anthropic', 
                     'openai', 'scraping', 'automation', 'machine learning', 'neural', 'transformer',
                     'gemini', 'mistral', 'deepseek', 'language model', 'chatbot', 'copilot']
        for sid in story_ids:
            try:
                story = fetch_json(f"https://hacker-news.firebaseio.com/v0/item/{sid}.json")
                title = story.get('title', '').lower()
                if any(k in title for k in keywords):
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
        print(f"    {len(stories)} AI-relevant stories from top 40")
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
        keywords = ['ai', 'agent', 'llm', 'model', 'openclaw', 'gpt', 'claude', 'ml', 
                     'neural', 'transformer', 'scraping', 'copilot', 'chat', 'inference',
                     'diffusion', 'vision', 'embedding', 'rag', 'prompt', 'fine-tun']
        for art in articles[:25]:
            h2 = art.css('h2 a')
            if h2:
                href = h2[0].attrib.get('href', '')
                name = href.strip('/')
                
                p = art.css('p')
                desc = (p[0].text or "").strip() if p else ""
                
                stars_text = ""
                spans = art.css('span')
                for s in spans:
                    t = (s.text or "").strip()
                    if 'stars today' in t:
                        stars_text = t
                        break
                
                combined = f"{name} {desc}".lower()
                if any(k in combined for k in keywords):
                    repos.append({
                        "name": name,
                        "description": desc[:200],
                        "url": f"https://github.com{href}",
                        "stars_today": stars_text
                    })
        
        print(f"    {len(repos)} AI-relevant repos from trending")
        return repos[:10]
    except Exception as e:
        return {"error": str(e)}

def scrape_security():
    """Security news — AI/agent/cyber vulnerabilities"""
    print("[L2] Security news...")
    try:
        page = StealthyFetcher.fetch("https://www.bleepingcomputer.com/", headless=True, timeout=15000)
        articles = []
        seen = set()
        links = page.css('a')
        keywords = ['ai', 'agent', 'llm', 'vulnerability', 'security', 'hack', 'breach', 
                     'malware', 'chrome', 'api', 'ransomware', 'phishing', 'zero-day', 'exploit']
        for a in links:
            text = (a.text or "").strip()
            text = re.sub(r'\s+', ' ', text).strip()
            href = a.attrib.get('href', '')
            if text and 25 < len(text) < 200 and '/news/' in href and text not in seen:
                title_lower = text.lower()
                if any(k in title_lower for k in keywords):
                    seen.add(text)
                    articles.append({
                        "title": text[:200],
                        "url": href if href.startswith('http') else f"https://www.bleepingcomputer.com{href}",
                        "source": "BleepingComputer"
                    })
        print(f"    {len(articles)} security articles")
        return articles[:10]
    except Exception as e:
        return {"error": str(e)}

# ============================================================
# LAYER 3: Authenticated X search
# ============================================================

def scrape_x_profiles():
    """Scrape key X profiles via PlayWright + cookie auth + network interception"""
    print("[L3-lite] X profiles...")
    from scrapling.fetchers import PlayWrightFetcher
    
    auth_token = os.environ.get('X_AUTH_TOKEN', '')
    ct0_token = os.environ.get('X_CT0', '')
    
    profiles = ["OpenClawCode", "AnthropicAI", "defidevcorp"]
    tweets = []
    
    for handle in profiles:
        try:
            captured = []
            
            def capture_profile(page, _h=handle, _cap=captured):
                # Inject auth cookies so GraphQL endpoints work
                if auth_token and ct0_token:
                    page.context.add_cookies([
                        {'name': 'auth_token', 'value': auth_token, 'domain': '.x.com', 'path': '/', 'httpOnly': True, 'secure': True},
                        {'name': 'ct0', 'value': ct0_token, 'domain': '.x.com', 'path': '/', 'secure': True},
                    ])
                
                def on_response(response):
                    url = response.url
                    if ('UserTweets' in url or 'UserByScreenName' in url) and response.status == 200:
                        try:
                            body = response.body()
                            if body and len(body) > 200:
                                _cap.append(json.loads(body))
                        except:
                            pass
                
                page.on('response', on_response)
                page.goto(f'https://x.com/{_h}', timeout=15000)
                page.wait_for_timeout(5000)
                return page
            
            PlayWrightFetcher.fetch('https://x.com', headless=True,
                                    page_action=capture_profile, timeout=20000)
            
            added = 0
            for data in captured:
                # Try to find tweets in UserTweets response
                entries = []
                try:
                    timeline = data.get('data', {}).get('user', {}).get('result', {}).get('timeline_v2', {}).get('timeline', {})
                    for inst in timeline.get('instructions', []):
                        entries.extend(inst.get('entries', []))
                except:
                    pass
                
                for entry in entries[:5]:
                    try:
                        result = entry.get('content', {}).get('itemContent', {}).get('tweet_results', {}).get('result', {})
                        legacy = result.get('legacy') or result.get('tweet', {}).get('legacy', {})
                        text = legacy.get('full_text', '')
                        if text and len(text) > 20 and not text.startswith('RT @'):
                            tweets.append({
                                "handle": handle,
                                "text": text[:280],
                                "likes": legacy.get('favorite_count', 0),
                                "retweets": legacy.get('retweet_count', 0),
                                "source": "profile"
                            })
                            added += 1
                    except:
                        continue
            print(f"    @{handle}: {added} tweets")
        except Exception as e:
            print(f"    @{handle}: ERROR — {e}")
    
    return tweets[:15]

def scrape_x_search_authenticated():
    """Authenticated X search via PlayWright (Chromium) + cookie injection + network interception.
    IMPORTANT: Must use PlayWrightFetcher, NOT StealthyFetcher (Camoufox).
    X's GraphQL API blocks Camoufox but allows real Chromium."""
    print("[L3] X authenticated search (Chromium)...")
    
    from scrapling.fetchers import PlayWrightFetcher
    
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
            
            tweet_count = 0
            for data in captured:
                try:
                    instructions = data['data']['search_by_raw_query']['search_timeline']['timeline']['instructions']
                    for inst in instructions:
                        for entry in inst.get('entries', []):
                            try:
                                result = entry['content']['itemContent']['tweet_results']['result']
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
                                tweet_count += 1
                            except:
                                continue
                except:
                    continue
            print(f"    \"{query}\": {tweet_count} tweets")
        except Exception as e:
            print(f"    \"{query}\": ERROR — {e}")
    
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
        "layers": ["core", "expanded", "x_auth" if auth_token else "x_profiles_only"],
        "duration_sec": round(time.time() - t0, 1)
    })
    
    t1 = time.time()
    print(f"\n✅ Scrape complete in {t1-t0:.1f}s")
    
    # Summary
    total_bytes = sum(f.stat().st_size for f in RAW_DIR.glob('*.json'))
    print(f"Files: {len(list(RAW_DIR.glob('*.json')))} | Total: {total_bytes:,} bytes")

if __name__ == "__main__":
    main()
