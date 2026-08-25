#!/usr/bin/env python3
"""Batch image convert via ffmpeg (primary) + magick fallback."""
import argparse, shutil, subprocess, sys
from pathlib import Path

SUPPORTED = {"webp","png","jpg","jpeg","avif","jxl","heic","heif","tiff","bmp"}

def ffmpeg_available(): return shutil.which("ffmpeg") is not None
def magick_available():
    return shutil.which("magick") is not None or shutil.which("convert") is not None

def convert_one(src: Path, dst: Path, fmt: str, quality: int, resize: str, overwrite: bool):
    if dst.exists() and not overwrite:
        return False, "exists (skip, use --overwrite)"
    dst.parent.mkdir(parents=True, exist_ok=True)
    # choose tool
    if ffmpeg_available():
        # build ffmpeg cmd
        fmt = fmt.lower()
        if fmt in ("jpg","jpeg"):
            # mjpeg q:v 2-31, map quality 100-0 -> 2-10: q = 31 - quality*0.29 approx. simpler: use -q:v 2 for high, 10 for low
            # map quality 0-100 -> q:v 31->2
            qv = max(2, min(31, int(31 - (quality/100)*29)))
            cmd = ["ffmpeg","-y","-i",str(src),"-c:v","mjpeg",f"-q:v",str(qv)]
            if resize:
                # resize: 512 or 512x512
                if "x" in resize:
                    w,h = resize.split("x",1)
                    vf = f"scale={w}:{h}"
                else:
                    vf = f"scale={resize}:-1"
                cmd += ["-vf", vf]
            cmd += [str(dst)]
        elif fmt == "png":
            cmd = ["ffmpeg","-y","-i",str(src),"-c:v","png"]
            if resize:
                if "x" in resize:
                    w,h = resize.split("x",1)
                    vf = f"scale={w}:{h}"
                else:
                    vf = f"scale={resize}:-1"
                cmd += ["-vf", vf]
            cmd += [str(dst)]
        elif fmt == "webp":
            cmd = ["ffmpeg","-y","-i",str(src),"-c:v","libwebp","-quality",str(quality)]
            if resize:
                if "x" in resize: w,h = resize.split("x",1);vf=f"scale={w}:{h}"
                else: vf=f"scale={resize}:-1"
                cmd = cmd[:3] + ["-vf",vf] + cmd[3:]
            cmd += [str(dst)]
        elif fmt == "avif":
            crf = max(0, min(63, int(63 - quality*0.63)))
            cmd = ["ffmpeg","-y","-i",str(src),"-c:v","libaom-av1","-still-picture","1","-crf",str(crf),"-b:v","0"]
            if resize:
                if "x" in resize: w,h = resize.split("x",1);vf=f"scale={w}:{h}"
                else: vf=f"scale={resize}:-1"
                cmd += ["-vf",vf]
            cmd += [str(dst)]
        elif fmt == "jxl":
            # ffmpeg jxl via libjxl
            cmd = ["ffmpeg","-y","-i",str(src),"-c:v","libjxl","-quality",str(quality)]
            if resize:
                if "x" in resize: w,h = resize.split("x",1);vf=f"scale={w}:{h}"
                else: vf=f"scale={resize}:-1"
                cmd += ["-vf",vf]
            cmd += [str(dst)]
        else:
            cmd = None
        if cmd:
            r = subprocess.run(cmd, capture_output=True, text=True)
            if r.returncode == 0 and dst.exists() and dst.stat().st_size>0:
                return True, ""
            # ffmpeg failed -> fallback magick
            if magick_available():
                pass
            else:
                return False, r.stderr[:400]
    # magick fallback
    if magick_available():
        mag = shutil.which("magick") or "convert"
        # magick input -resize 512 -quality 75 output
        cmd = [mag, str(src)]
        if resize:
            if "x" in resize: cmd += ["-resize", resize]
            else: cmd += ["-resize", resize]
        cmd += ["-quality", str(quality), str(dst)]
        r = subprocess.run(cmd, capture_output=True, text=True)
        if r.returncode==0 and dst.exists():
            return True, ""
        return False, r.stderr[:400]
    return False, "no encoder available"

def main():
    ap = argparse.ArgumentParser(description="Batch image convert via ffmpeg/magick")
    ap.add_argument("--input", required=True, help="File or directory")
    ap.add_argument("--to", required=True, help="Target format: webp/png/jpg/avif/jxl/heic")
    ap.add_argument("--quality", type=int, default=None, help="Quality 0-100 (default 75 webp, 85 jpg, 60 avif)")
    ap.add_argument("--resize", help="Resize W or WxH (e.g. 512 or 512x512)")
    ap.add_argument("--out", help="Single output path (only for single file input)")
    ap.add_argument("--out-dir", help="Output directory (batch)")
    ap.add_argument("--overwrite", action="store_true", help="Overwrite existing")
    ap.add_argument("--recursive", action="store_true", help="Recurse subdirs")
    ap.add_argument("--dry-run", action="store_true", help="Preview only")
    ap.add_argument("--keep", action="store_true", default=True, help="Keep originals (default true)")
    ap.add_argument("--delete", action="store_true", help="Delete original after convert (use with care)")
    args = ap.parse_args()
    fmt = args.to.lower().lstrip(".")
    if fmt == "jpg": fmt="jpg"
    if fmt not in SUPPORTED: sys.exit(f"Unsupported fmt {fmt}, choose {SUPPORTED}")
    if args.quality is None:
        args.quality = 75 if fmt=="webp" else 85 if fmt in ("jpg","jpeg") else 60 if fmt=="avif" else 75
    args.quality = max(0,min(100,args.quality))

    inp = Path(args.input)
    if not inp.exists(): sys.exit(f"Input not found: {inp}")
    files=[]
    if inp.is_file():
        files=[inp]
    else:
        if args.recursive:
            # collect all files with image suffix via rglob
            files = [p for p in inp.rglob("*") if p.is_file() and p.suffix.lower() in (".png",".jpg",".jpeg",".webp",".avif",".jxl",".heic",".heif",".tiff",".bmp")]
        else:
            exts = ["*.png","*.jpg","*.jpeg","*.webp","*.avif","*.jxl","*.heic","*.tiff","*.bmp","*.PNG","*.JPG"]
            for ext in exts:
                files.extend(inp.glob(ext))
        # dedupe + skip already target fmt
        files = sorted(set(files))
        # skip files already in target format (avoid .converted.webp churn)
        files = [f for f in files if f.suffix.lower() != f".{fmt.lower()}"]

    # filter: skip files already in target fmt if same dir
    if args.out and len(files)!=1: sys.exit("--out only for single file input")
    print(f"Found {len(files)} files -> {fmt} quality={args.quality} resize={args.resize or 'none'}")
    if not files: sys.exit("No images found")
    for f in files[:5]:
        print(f"  {f} ({f.stat().st_size/1024:.1f}KB)")
    if len(files)>5: print(f"  ... +{len(files)-5} more")
    if args.dry_run:
        for f in files:
            dst = Path(args.out) if args.out else (Path(args.out_dir)/ (f.stem + "." + fmt) if args.out_dir else f.with_suffix("."+fmt))
            print(f"  {f} -> {dst}")
        return
    ok=fail=saved=orig=0
    for src in files:
        if args.out:
            dst = Path(args.out)
        elif args.out_dir:
            # preserve relative structure if recursive
            try:
                rel = src.relative_to(inp)
                dst = Path(args.out_dir) / rel.with_suffix("."+fmt)
            except ValueError:
                dst = Path(args.out_dir) / (src.stem + "."+fmt)
        else:
            dst = src.with_suffix("."+fmt)
            if dst==src:  # same ext
                dst = src.with_name(src.stem + f".converted.{fmt}")

        success, msg = convert_one(src, dst, fmt, args.quality, args.resize, args.overwrite)
        if success:
            ok+=1
            sz0=src.stat().st_size
            sz1=dst.stat().st_size
            saved+=sz0-sz1
            orig+=sz0
            pct = (1 - sz1/sz0)*100 if sz0 else 0
            print(f"  ✓ {src.name} -> {dst.name} {sz0/1024:.0f}K->{sz1/1024:.0f}K ({pct:+.0f}%)")
            if args.delete:
                # safe delete only if dst exists and smaller? still warn
                try:
                    src.unlink()
                    print(f"    deleted original {src}")
                except Exception as e:
                    print(f"    delete failed: {e}", file=sys.stderr)
        else:
            fail+=1
            print(f"  ✗ {src.name}: {msg}", file=sys.stderr)
    print(f"\nDone: {ok} ok, {fail} fail, saved {saved/1024/1024:.1f}MB ({saved/orig*100:.0f}% reduction)" if orig else f"\nDone: {ok} ok")
    if fail: sys.exit(1)

if __name__=="__main__": main()
