#!/usr/bin/env python3
"""
Asset Fetcher — reusable tool for generating images (DALL-E 3) and
downloading + converting audio (Pixabay / Freesound CC0 / direct URL).

All audio sources are license-safe for commercial apps:
  - Pixabay License: royalty-free, no attribution, commercial OK
  - Freesound CC0: public domain, no restrictions

Usage:
    # Generate a DALL-E 3 image
    python3 tools/asset_fetcher.py image \
        --prompt "A children's book neighborhood scene..." \
        --output Resources/neighborhood_base.png \
        --size 1792x1024

    # Download + convert audio from a direct URL
    python3 tools/asset_fetcher.py audio \
        --url "https://cdn.pixabay.com/audio/2024/..." \
        --output Resources/ambient_rainy.m4a \
        --format m4a

    # Search Pixabay for a sound, download first match
    python3 tools/asset_fetcher.py search-audio \
        --query "rain patter loop" \
        --source pixabay \
        --output Resources/ambient_rainy.m4a \
        --format m4a

    # Search Freesound CC0 for a sound (preview quality, no OAuth needed)
    python3 tools/asset_fetcher.py search-audio \
        --query "birds chirping" \
        --source freesound \
        --output Resources/ambient_sunny.m4a \
        --format m4a

    # Batch mode — process a JSON manifest of all assets
    python3 tools/asset_fetcher.py batch --manifest tools/weather_assets.json

    # List Pixabay/Freesound results without downloading (for picking)
    python3 tools/asset_fetcher.py list-audio \
        --query "child giggle" \
        --source pixabay

API key: ~/.claude/secrets/openai_api_key
Requires: ffmpeg (for audio format conversion)
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import urllib.parse
from pathlib import Path

SECRETS_DIR = Path.home() / ".claude" / "secrets"
OPENAI_KEY_FILE = SECRETS_DIR / "openai_api_key"

# License-safe audio sources
AUDIO_SOURCES = {
    "pixabay": {
        "name": "Pixabay",
        "license": "Pixabay License — royalty-free, no attribution, commercial OK",
        "search_url": "https://pixabay.com/sound-effects/search/{query}/",
    },
    "freesound": {
        "name": "Freesound CC0",
        "license": "CC0 Public Domain — no restrictions",
        "search_url": "https://freesound.org/search/?q={query}&f=license:%22Creative+Commons+0%22&s=rating+desc",
    },
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def get_openai_key():
    if OPENAI_KEY_FILE.exists():
        return OPENAI_KEY_FILE.read_text().strip()
    env_key = os.environ.get("OPENAI_API_KEY")
    if env_key:
        return env_key
    print("ERROR: No OpenAI API key found.", file=sys.stderr)
    print("  Place it in ~/.claude/secrets/openai_api_key or set $OPENAI_API_KEY", file=sys.stderr)
    sys.exit(1)


def _request(url: str, accept: str = "*/*") -> bytes:
    """Make an HTTP GET request with browser-like headers."""
    import http.cookiejar
    cj = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
    req = urllib.request.Request(url, headers={
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                      "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Accept": accept,
        "Accept-Language": "en-US,en;q=0.9",
        "Sec-Fetch-Dest": "document",
        "Sec-Fetch-Mode": "navigate",
        "Sec-Fetch-Site": "none",
        "Sec-Fetch-User": "?1",
        "Upgrade-Insecure-Requests": "1",
    })
    with opener.open(req, timeout=30) as resp:
        return resp.read()


def download_file(url: str, output_path: str) -> str:
    """Download a file from URL to output_path."""
    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)

    print(f"  Downloading: {url[:100]}...")
    data = _request(url)
    output.write_bytes(data)
    print(f"  Saved: {output} ({len(data) / 1024:.0f} KB)")
    return str(output)


def convert_with_ffmpeg(input_path: str, output_path: str, format_hint: str = None):
    """Convert audio/image using ffmpeg."""
    if not shutil.which("ffmpeg"):
        print("  ERROR: ffmpeg not found — install with: sudo apt install ffmpeg", file=sys.stderr)
        shutil.copy2(input_path, output_path)
        return

    output = Path(output_path)
    fmt = format_hint or output.suffix.lstrip(".").lower()

    if fmt == "m4a":
        # AAC in M4A container — compressed, good for ambient loops
        cmd = ["ffmpeg", "-y", "-i", input_path,
               "-c:a", "aac", "-b:a", "128k", "-ac", "1", output_path]
    elif fmt == "caf":
        # 16-bit PCM in CAF container — uncompressed, low latency for SFX
        cmd = ["ffmpeg", "-y", "-i", input_path,
               "-c:a", "pcm_s16le", "-ar", "44100", "-ac", "1", "-f", "caf", output_path]
    elif fmt == "wav":
        cmd = ["ffmpeg", "-y", "-i", input_path,
               "-c:a", "pcm_s16le", "-ar", "44100", "-ac", "1", output_path]
    else:
        cmd = ["ffmpeg", "-y", "-i", input_path, output_path]

    print(f"  Converting → {fmt}: {output.name}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"  ERROR: ffmpeg conversion failed:\n{result.stderr[-500:]}", file=sys.stderr)
        sys.exit(1)

    print(f"  Converted: {output} ({os.path.getsize(output_path) / 1024:.0f} KB)")


# ---------------------------------------------------------------------------
# Image generation (DALL-E 3)
# ---------------------------------------------------------------------------

def generate_image(prompt: str, output_path: str, size: str = "1792x1024", quality: str = "standard"):
    """Generate an image with DALL-E 3 and save to output_path."""
    from openai import OpenAI

    client = OpenAI(api_key=get_openai_key())
    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)

    print(f"Generating image with DALL-E 3...")
    print(f"  Prompt: {prompt[:100]}{'...' if len(prompt) > 100 else ''}")
    print(f"  Size: {size}, Quality: {quality}")

    response = client.images.generate(
        model="dall-e-3",
        prompt=prompt,
        size=size,
        quality=quality,
        n=1,
        response_format="url",
    )

    image_url = response.data[0].url
    revised_prompt = response.data[0].revised_prompt
    print(f"  Revised prompt: {revised_prompt[:120]}...")

    image_data = _request(image_url)

    if output.suffix.lower() == ".png":
        output.write_bytes(image_data)
        print(f"  Saved: {output} ({len(image_data) / 1024:.0f} KB)")
    else:
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
            tmp.write(image_data)
            tmp_path = tmp.name
        try:
            convert_with_ffmpeg(tmp_path, str(output))
        finally:
            os.unlink(tmp_path)

    return str(output)


# ---------------------------------------------------------------------------
# Audio: search + download
# ---------------------------------------------------------------------------

def _search_pixabay(query: str) -> list[dict]:
    """Search Pixabay sound effects, return list of {url, title, slug}.

    Pixabay serves audio via JavaScript, so we can't extract direct CDN URLs
    from the HTML. Instead we extract the sound page slugs so the user (or
    Claude via WebSearch) can find the direct download URL.

    If slug pages contain an embedded audio URL we grab it; otherwise we
    return the page URL for manual download.
    """
    encoded_q = urllib.parse.quote_plus(query)
    search_url = f"https://pixabay.com/sound-effects/search/{encoded_q}/"

    print(f"  Searching Pixabay: {search_url}")
    try:
        html = _request(search_url, accept="text/html").decode("utf-8", errors="replace")
    except Exception as e:
        print(f"  WARNING: Pixabay search failed: {e}", file=sys.stderr)
        return []

    # Try direct CDN audio URLs first (sometimes present in JSON-LD or preload)
    cdn_patterns = [
        r'https://cdn\.pixabay\.com/audio/\d{4}/[^"\'\\<>\s})]+\.(?:mp3|wav|ogg|m4a)',
        r'https://cdn\.pixabay\.com/download/audio[^"\'\\<>\s})]+\.(?:mp3|wav|ogg|m4a)',
    ]
    direct_urls = []
    for pat in cdn_patterns:
        direct_urls.extend(re.findall(pat, html))

    if direct_urls:
        seen = set()
        results = []
        for url in direct_urls:
            url = url.rstrip(".,;")
            if url not in seen:
                seen.add(url)
                name = Path(urllib.parse.urlparse(url).path).stem
                results.append({"url": url, "title": name, "source": "pixabay"})
        return results

    # Fallback: extract individual sound page links
    # Pixabay sound pages look like: /sound-effects/rain-patter-12345/
    slug_pattern = r'/sound-effects/([\w-]+-\d+)/'
    slugs = re.findall(slug_pattern, html)

    # Deduplicate preserving order, skip "search" slugs
    seen = set()
    results = []
    for slug in slugs:
        if slug not in seen and not slug.startswith("search"):
            seen.add(slug)
            page_url = f"https://pixabay.com/sound-effects/{slug}/"
            title = slug.rsplit("-", 1)[0].replace("-", " ").title()
            results.append({"url": page_url, "title": title, "source": "pixabay",
                            "is_page": True, "slug": slug})

    return results


def _search_freesound(query: str) -> list[dict]:
    """Search Freesound for CC0 sounds, return preview URLs (no OAuth needed)."""
    encoded_q = urllib.parse.quote_plus(query)
    # Freesound search page filtered to CC0 only
    search_url = (
        f"https://freesound.org/search/?q={encoded_q}"
        f"&f=license:%22Creative+Commons+0%22&s=rating+desc"
    )

    print(f"  Searching Freesound CC0: {search_url}")
    try:
        html = _request(search_url, accept="text/html").decode("utf-8", errors="replace")
    except Exception as e:
        print(f"  WARNING: Freesound search failed: {e}", file=sys.stderr)
        return []

    # Extract preview MP3 URLs from Freesound HTML
    # Freesound embeds preview URLs in data-mp3 attributes or player elements
    preview_pattern = r'https://freesound\.org/data/previews/\d+/\d+_\d+-[a-z]+-preview[^"\'\\<>\s]*\.mp3'
    raw_matches = re.findall(preview_pattern, html)

    # Also try CDN pattern
    cdn_pattern = r'https://cdn\.freesound\.org/previews/\d+/\d+_\d+-[a-z]+-preview[^"\'\\<>\s]*\.mp3'
    raw_matches.extend(re.findall(cdn_pattern, html))

    seen = set()
    results = []
    for url in raw_matches:
        url = url.rstrip(".,;")
        if url not in seen:
            seen.add(url)
            name = Path(urllib.parse.urlparse(url).path).stem
            results.append({"url": url, "title": name, "source": "freesound-cc0"})

    return results


def search_audio(query: str, source: str = "pixabay") -> list[dict]:
    """Search for audio across supported sources."""
    if source == "pixabay":
        return _search_pixabay(query)
    elif source == "freesound":
        return _search_freesound(query)
    elif source == "all":
        results = _search_pixabay(query)
        results.extend(_search_freesound(query))
        return results
    else:
        print(f"  ERROR: Unknown source '{source}'. Use: pixabay, freesound, all", file=sys.stderr)
        return []


def list_audio(query: str, source: str = "pixabay"):
    """List search results without downloading."""
    results = search_audio(query, source)
    if not results:
        print(f"  No results found for '{query}' on {source}")
        return

    print(f"\n  Found {len(results)} result(s) for '{query}':")
    for i, r in enumerate(results[:10]):
        license_tag = "Pixabay License" if r["source"] == "pixabay" else "CC0"
        print(f"    [{i}] [{license_tag}] {r['title']}")
        print(f"        {r['url']}")


def _try_extract_audio_from_page(page_url: str) -> str | None:
    """Try to fetch a Pixabay/Freesound sound page and extract a direct audio URL."""
    try:
        html = _request(page_url, accept="text/html").decode("utf-8", errors="replace")
    except Exception:
        return None

    # Look for direct audio file URLs in the page
    patterns = [
        r'https://cdn\.pixabay\.com/audio/\d{4}/[^"\'\\<>\s})]+\.(?:mp3|wav|ogg)',
        r'https://cdn\.pixabay\.com/download/audio[^"\'\\<>\s})]+\.(?:mp3|wav|ogg)',
        r'https://cdn\.freesound\.org/previews/[^"\'\\<>\s})]+\.(?:mp3|wav|ogg)',
        r'https://freesound\.org/data/previews/[^"\'\\<>\s})]+\.(?:mp3|wav|ogg)',
    ]
    for pat in patterns:
        matches = re.findall(pat, html)
        if matches:
            return matches[0].rstrip(".,;")

    return None


def search_and_download_audio(query: str, output_path: str, fmt: str = None,
                               source: str = "pixabay", pick: int = 0):
    """Search for audio, download the best (or Nth) match, convert to target format."""
    results = search_audio(query, source)

    if not results:
        print(f"  No results found for '{query}' on {source}.", file=sys.stderr)
        print(f"  TIP: Try a different query, source, or provide a direct --url.", file=sys.stderr)
        sys.exit(1)

    print(f"  Found {len(results)} result(s):")
    for i, r in enumerate(results[:5]):
        marker = " <<<" if i == pick else ""
        page_tag = " [page link]" if r.get("is_page") else ""
        print(f"    [{i}] {r['title']} ({r['source']}){page_tag}{marker}")

    if pick >= len(results):
        pick = 0
    chosen = results[pick]

    # If we got a page URL instead of a direct audio URL, try to extract the audio
    if chosen.get("is_page"):
        print(f"  Got page URL, attempting to extract audio from: {chosen['url']}")
        direct_url = _try_extract_audio_from_page(chosen["url"])
        if direct_url:
            print(f"  Found direct audio URL: {direct_url[:80]}...")
            chosen["url"] = direct_url
        else:
            print(f"  Could not extract audio URL from page.", file=sys.stderr)
            print(f"  Page: {chosen['url']}", file=sys.stderr)
            print(f"  TIP: Visit the page in a browser, copy the download URL,", file=sys.stderr)
            print(f"       then use: python3 tools/asset_fetcher.py audio --url <URL> --output {output_path}", file=sys.stderr)
            sys.exit(1)

    print(f"  Downloading: [{pick}] {chosen['title']} ({chosen['source']})")
    return download_audio(chosen["url"], output_path, fmt)


def download_audio(url: str, output_path: str, fmt: str = None):
    """Download audio from URL and convert to target format."""
    output = Path(output_path)
    fmt = fmt or output.suffix.lstrip(".").lower()

    # Infer source extension from URL
    url_path = Path(urllib.parse.urlparse(url).path)
    src_ext = url_path.suffix or ".mp3"

    with tempfile.NamedTemporaryFile(suffix=src_ext, delete=False) as tmp:
        tmp_path = tmp.name

    try:
        download_file(url, tmp_path)

        src_fmt = Path(tmp_path).suffix.lstrip(".").lower()
        if src_fmt == fmt:
            output.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(tmp_path, output_path)
            print(f"  No conversion needed — saved as {output}")
        else:
            output.parent.mkdir(parents=True, exist_ok=True)
            convert_with_ffmpeg(tmp_path, output_path, fmt)
    finally:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)

    return output_path


# ---------------------------------------------------------------------------
# Batch mode
# ---------------------------------------------------------------------------

def run_batch(manifest_path: str):
    """Process a JSON manifest of assets to fetch.

    Manifest format:
    {
        "output_dir": "path/to/Resources",
        "images": [
            {
                "name": "file.png",
                "prompt": "DALL-E 3 prompt text",
                "size": "1792x1024",       // optional, default 1792x1024
                "quality": "standard"       // optional, default standard
            }
        ],
        "audio": [
            {
                "name": "ambient_rain.m4a",
                "search": "rain patter",    // search query — OR —
                "url": "https://...",       // direct download URL
                "source": "pixabay",        // pixabay (default) | freesound | all
                "format": "m4a",            // m4a | caf | wav (inferred from name if omitted)
                "pick": 0                   // which search result to use (default: 0 = first)
            }
        ]
    }

    Licensing:
      - Images: generated by DALL-E 3 (you own the output)
      - Audio from Pixabay: Pixabay License (royalty-free, no attribution, commercial OK)
      - Audio from Freesound CC0: public domain (no restrictions)
    """
    manifest = json.loads(Path(manifest_path).read_text())
    output_dir = Path(manifest.get("output_dir", "."))
    output_dir.mkdir(parents=True, exist_ok=True)

    results = {"images": [], "audio": [], "errors": []}

    # Process images
    for img in manifest.get("images", []):
        name = img["name"]
        output_path = str(output_dir / name)
        try:
            print(f"\n{'=' * 60}")
            print(f"IMAGE: {name}")
            print(f"{'=' * 60}")
            generate_image(
                prompt=img["prompt"],
                output_path=output_path,
                size=img.get("size", "1792x1024"),
                quality=img.get("quality", "standard"),
            )
            results["images"].append({"name": name, "path": output_path, "status": "ok"})
        except Exception as e:
            print(f"  ERROR: {e}", file=sys.stderr)
            results["errors"].append({"name": name, "error": str(e)})

    # Process audio
    for aud in manifest.get("audio", []):
        name = aud["name"]
        output_path = str(output_dir / name)
        fmt = aud.get("format", Path(name).suffix.lstrip("."))
        source = aud.get("source", "pixabay")
        pick = aud.get("pick", 0)
        try:
            print(f"\n{'=' * 60}")
            print(f"AUDIO: {name} (source: {source})")
            print(f"  License: {AUDIO_SOURCES.get(source, {}).get('license', 'unknown')}")
            print(f"{'=' * 60}")
            if "url" in aud:
                download_audio(aud["url"], output_path, fmt)
            elif "search" in aud:
                search_and_download_audio(aud["search"], output_path, fmt, source, pick)
            else:
                print(f"  SKIP: No 'url' or 'search' for {name}", file=sys.stderr)
                results["errors"].append({"name": name, "error": "no url or search"})
                continue
            results["audio"].append({"name": name, "path": output_path, "status": "ok"})
        except Exception as e:
            print(f"  ERROR: {e}", file=sys.stderr)
            results["errors"].append({"name": name, "error": str(e)})

    # Summary
    print(f"\n{'=' * 60}")
    print(f"BATCH SUMMARY")
    print(f"{'=' * 60}")
    print(f"  Output dir: {output_dir}")
    print(f"  Images: {len(results['images'])} fetched")
    print(f"  Audio:  {len(results['audio'])} fetched")
    if results["errors"]:
        print(f"  Errors: {len(results['errors'])}")
        for e in results["errors"]:
            print(f"    ✗ {e['name']}: {e['error']}")
    else:
        print(f"  All assets fetched successfully.")

    # Write results JSON next to manifest
    results_path = Path(manifest_path).with_suffix(".results.json")
    results_path.write_text(json.dumps(results, indent=2))
    print(f"\n  Results written to: {results_path}")

    return results


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Asset Fetcher — DALL-E 3 images + Pixabay/Freesound audio",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Audio sources (all license-safe for commercial apps):
  pixabay   — Pixabay License: royalty-free, no attribution, commercial OK
  freesound — CC0 Public Domain: no restrictions whatsoever
  all       — search both, pixabay results first

Audio formats:
  m4a  — AAC compressed, good for ambient loops (small files)
  caf  — PCM 16-bit uncompressed, good for one-shot SFX (low latency)
  wav  — PCM 16-bit uncompressed, universal compatibility
""",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    # image
    img = sub.add_parser("image", help="Generate a DALL-E 3 image")
    img.add_argument("--prompt", required=True, help="Image generation prompt")
    img.add_argument("--output", required=True, help="Output file path (.png)")
    img.add_argument("--size", default="1792x1024",
                     choices=["1024x1024", "1024x1792", "1792x1024"],
                     help="Image dimensions (default: 1792x1024)")
    img.add_argument("--quality", default="standard", choices=["standard", "hd"],
                     help="DALL-E quality tier (default: standard)")

    # audio
    aud = sub.add_parser("audio", help="Download + convert audio from a direct URL")
    aud.add_argument("--url", required=True, help="Direct audio file URL")
    aud.add_argument("--output", required=True, help="Output file path")
    aud.add_argument("--format", help="Target format: m4a, caf, wav (inferred from extension)")

    # search-audio
    sa = sub.add_parser("search-audio", help="Search Pixabay/Freesound and download audio")
    sa.add_argument("--query", required=True, help="Search query (e.g. 'rain patter loop')")
    sa.add_argument("--output", required=True, help="Output file path")
    sa.add_argument("--format", help="Target format: m4a, caf, wav")
    sa.add_argument("--source", default="pixabay", choices=["pixabay", "freesound", "all"],
                    help="Where to search (default: pixabay)")
    sa.add_argument("--pick", type=int, default=0, help="Which result to download (default: 0 = first)")

    # list-audio
    la = sub.add_parser("list-audio", help="List search results without downloading")
    la.add_argument("--query", required=True, help="Search query")
    la.add_argument("--source", default="pixabay", choices=["pixabay", "freesound", "all"],
                    help="Where to search (default: pixabay)")

    # batch
    bat = sub.add_parser("batch", help="Process a JSON asset manifest")
    bat.add_argument("--manifest", required=True, help="Path to manifest JSON file")

    args = parser.parse_args()

    if args.command == "image":
        generate_image(args.prompt, args.output, args.size, args.quality)
    elif args.command == "audio":
        download_audio(args.url, args.output, args.format)
    elif args.command == "search-audio":
        search_and_download_audio(args.query, args.output, args.format, args.source, args.pick)
    elif args.command == "list-audio":
        list_audio(args.query, args.source)
    elif args.command == "batch":
        run_batch(args.manifest)


if __name__ == "__main__":
    main()
