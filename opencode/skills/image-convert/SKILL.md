---
name: image-convert
description: Convert images between formats (png/jpg/webp/avif/jxl) via ffmpeg (primary) + magick fallback. Batch dir, single file, quality/resize control. Use when user wants convert image, png to webp, batch webp, compress images, or optimize thumbnails.
---

# Image Convert

Batch convert images local. `ffmpeg` primary (libwebp, png, mjpeg, libaom-av1, libjxl). `magick` fallback for exotic. Never reads outside allowed dirs without explicit path.

## Tool Map

* `ffmpeg -c:v libwebp -quality 75` -> webp (default). Also `png`, `mjpeg` (jpg), `libaom-av1` (avif), `libjxl` (jxl). Probe `ffmpeg -encoders | grep -i webp`
* `magick input.png -quality 75 output.webp` -> fallback if ffmpeg missing codec
* Inputs: single file, glob `*.png`, or directory `projects/*/assets/thumbnails/` (recursive optional)
* Outputs: same basename with new ext, or `--out-dir` / `--out` explicit

## Helper

`scripts/convert.py` handles glob, batch, resize, quality, keep-structure. Sequential, no parallel ffmpeg to avoid I/O thrash.

```bash
# single
python ~/.config/opencode/skills/image-convert/scripts/convert.py --input input.png --to webp --quality 75 --out out.webp
# batch dir -> webp (default quality 75)
python ~/.config/opencode/skills/image-convert/scripts/convert.py --input projects/01_the_witches_of_thessaly/assets/thumbnails --to webp
# batch png -> jpg quality 85, overwrite
python ~/.config/opencode/skills/image-convert/scripts/convert.py --input ./renders --to jpg --quality 85 --overwrite
# resize thumbnail while convert (e.g. 512px wide, keep aspect)
python ~/.config/opencode/skills/image-convert/scripts/convert.py --input ./assets --to webp --resize 512 --quality 80
# recursive
python ~/.config/opencode/skills/image-convert/scripts/convert.py --input projects --to avif --recursive --quality 60
# dry-run preview
python ~/.config/opencode/skills/image-convert/scripts/convert.py --input ./thumbnails --to webp --dry-run
```

Args: `--input` (file/dir), `--to {webp,png,jpg,jpeg,avif,jxl,heic}`, `--quality 0-100` (default 75 webp/avif, 92 png ignored, 85 jpg), `--resize WIDTH` (or `WxH`), `--out / --out-dir`, `--overwrite`, `--recursive`, `--keep` (keep original), `--dry-run`

## Agent Steps

1. List inputs: `ls -1 <input>` or glob via script. Show count + sample.
2. Check codecs: `ffmpeg -encoders | grep -i <to>` fallback `magick -list format`.
3. Run `convert.py` (sequential). Log each `input -> output (saved X%)`.
4. Verify: `ls -lh <out-dir>`, `ffprobe` or `identify` sample, report total saved.
5. For telos thumbs: default `--to webp --quality 75` halves size (`1M png -> ~150K webp`). Save alongside or replace per user choice (ask if overwrite).

## Manual ffmpeg (if script not needed)

```bash
ffmpeg -y -i input.png -c:v libwebp -quality 75 output.webp
ffmpeg -y -i input.png -vf scale=512:-1 -c:v libwebp -quality 80 output.webp
# jpg
ffmpeg -y -i input.png -c:v mjpeg -q:v 3 output.jpg  # q:v 2-5 (2 best)
# avif (slow)
ffmpeg -y -i input.png -c:v libaom-av1 -still-picture 1 -crf 30 -b:v 0 output.avif
```

Prefer script for batch — handles concat, errors, keeps.

## Notes

* Use `png` lossless `ffmpeg -i in.webp -c:v png out.png` no quality.
* `heic` needs `libheif` — often missing, fallback magick.
* Never `rm` originals unless `--overwrite` or user explicit keep. Default keep both until user confirms.
* Telos: thumbs in `projects/*/assets/thumbnails/*.png` -> suggest `python .../convert.py --input projects/01.../assets/thumbnails --to webp --quality 75` saves repo size (<5GB).
