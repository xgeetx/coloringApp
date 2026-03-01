---
description: Generate images (DALL-E 3) and download audio (Pixabay/Freesound CC0) for project assets
---

# Asset Fetcher

Reusable tool for sourcing project assets. Uses `tools/asset_fetcher.py`.

## Sources & Licensing

| Source | What | License |
|--------|------|---------|
| **DALL-E 3** | Image generation | You own the output — commercial OK |
| **Pixabay** | Sound effects | Pixabay License — royalty-free, no attribution, commercial OK |
| **Freesound CC0** | Sound effects | CC0 Public Domain — no restrictions |

All sources are safe for paid apps with no attribution requirements.

## Commands

### Generate an image
```bash
python3 tools/asset_fetcher.py image \
    --prompt "description of what you need" \
    --output path/to/output.png \
    --size 1792x1024 \
    --quality standard
```
Sizes: `1024x1024`, `1024x1792`, `1792x1024`. Quality: `standard` or `hd`.

### Download audio from a known URL
```bash
python3 tools/asset_fetcher.py audio \
    --url "https://cdn.pixabay.com/audio/..." \
    --output path/to/output.m4a \
    --format m4a
```

### Search and download audio
```bash
python3 tools/asset_fetcher.py search-audio \
    --query "rain patter loop" \
    --source pixabay \
    --output path/to/output.m4a \
    --format m4a \
    --pick 0
```
Sources: `pixabay` (default), `freesound`, `all`. Use `--pick N` to select Nth result.

### Browse results without downloading
```bash
python3 tools/asset_fetcher.py list-audio --query "child giggle" --source pixabay
```

### Batch mode (recommended for multi-asset tasks)
```bash
python3 tools/asset_fetcher.py batch --manifest tools/weather_assets.json
```

## Manifest JSON Format

Create a manifest describing all needed assets. The tool fetches everything in one run.

```json
{
  "output_dir": "path/to/Resources",
  "images": [
    {
      "name": "background.png",
      "prompt": "DALL-E 3 prompt describing the image",
      "size": "1792x1024",
      "quality": "standard"
    }
  ],
  "audio": [
    {
      "name": "ambient_rain.m4a",
      "search": "rain patter loop",
      "source": "pixabay",
      "format": "m4a"
    },
    {
      "name": "sfx_click.caf",
      "url": "https://direct-download-url.com/click.mp3",
      "format": "caf"
    }
  ]
}
```

Audio entries use EITHER `"search"` (auto-find) or `"url"` (direct download).

## Audio Formats

| Format | Use case | Encoding |
|--------|----------|----------|
| `.m4a` | Ambient loops | AAC compressed — small files |
| `.caf` | One-shot SFX | PCM 16-bit — low latency |
| `.wav` | Universal | PCM 16-bit — large files |

Requires `ffmpeg` for format conversion.

## Workflow

1. Write a manifest JSON describing what you need (prompts for images, search terms for audio)
2. Run: `python3 tools/asset_fetcher.py batch --manifest your_manifest.json`
3. Review results — re-run individual commands to tweak any assets
4. If Pixabay search misses, try `list-audio` to browse, or use `--source freesound`
5. If search fails entirely, use WebSearch to find a direct URL, then `audio --url`

## Existing Manifests

- `tools/weather_assets.json` — Weather Fun app (7 images + 8 audio files)
