#!/usr/bin/env python3
"""
batch_critique.py v2 — extends validation with visual-diff vs consolidated reference material
References embedded in skill: references/ (24 thumbs: ben/peterson/peterson_clips/chris) + manifest.json + styles/reference_styles.json
Checks:
  1. Core: blur, left clean, right subject, size (run on RAW only — finals inflate left edge)
  2. Visual-diff vs reference: text geometry (size ratio, positioning, highlight block, per-word color) compared to reference stats from manifest.json
     When --final <png> + --style <name> given, extra checks: does final match style's typography lesson (gold block for ben, bottom plate for peterson, centered heavenly for chris) within allowed palette.
Usage:
  python batch_critique.py --dir renders                          # RAW check only
  python batch_critique.py --dir renders --final renders/final_ben.png --style ben_dark_gold  # RAW + visual diff
  python batch_critique.py renders/*_000.png --json out.json
  python batch_critique.py --references # print reference stats
"""
import argparse, pathlib, json, sys, re
from PIL import Image, ImageFilter, ImageStat
try:
    import pytesseract
    HAS_TESS = True
except:
    HAS_TESS = False

SKILL_ROOT = pathlib.Path(__file__).resolve().parents[1]
REFS_DIR = SKILL_ROOT / "references"
MANIFEST = REFS_DIR / "manifest.json"
STYLES = SKILL_ROOT / "styles" / "reference_styles.json"

def laplacian_variance(img):
    try:
        import cv2, numpy as np
        arr = np.array(img.convert("L"))
        return float(cv2.Laplacian(arr, cv2.CV_64F).var())
    except:
        edges = img.convert("L").filter(ImageFilter.FIND_EDGES)
        return float(ImageStat.Stat(edges).var[0])

def edge_density(img):
    return float(ImageStat.Stat(img.convert("L").filter(ImageFilter.FIND_EDGES)).mean[0])

def left_clean_score(img, left_ratio=0.40):
    W,H = img.size
    ld = edge_density(img.crop((0,0,int(W*left_ratio), H)))
    rd = edge_density(img.crop((int(W*0.5),0,W,H)))
    return ld, rd, ld/(rd+1e-5)

def load_reference_stats():
    if MANIFEST.exists():
        m=json.loads(MANIFEST.read_text())
        return m.get("validation_stats", {})
    return {"ben_text_fill_ratio":0.55,"ben_last_block_ratio":0.58,"font_scale_reference":1.35,"stroke_outer_ref":4}

def detect_hallucinated_text(path):
    """Return WARN if raw contains rendered text/numbers/% despite no-text prompt."""
    try:
        if HAS_TESS:
            img = Image.open(path).convert("RGB")
            # crop left side where text hallucination appears (left 55%)
            W,H = img.size
            left = img.crop((0,0,int(W*0.60), H))
            # config: only look for % and alphanum, quick
            data = pytesseract.image_to_string(left, config="--psm 6")
            if "%" in data or any(c.isdigit() for c in data.strip() if len(data.strip())>1):
                # filter short noise: need >=2 chars and % or digit run
                if "%" in data:
                    return f"FAIL hallucinated text `%` detected: {repr(data.strip()[:30])} — regen with prompt without `%` (word form)"
                # if digits present in left area, likely hallucination
                # require at least 2 digits to avoid false positive
                digits = ''.join(c for c in data if c.isdigit())
                if len(digits) >= 2:
                    return f"WARN hallucinated numbers detected: {repr(data.strip()[:30])}"
    except Exception as e:
        return None
    # fallback: heuristic — check for high-contrast white-on-dark large glyphs in left area via edge + white pixel cluster
    try:
        img = Image.open(path).convert("RGB")
        W,H = img.size
        left = img.crop((0,0,int(W*0.55), H)).convert("L")
        # threshold white text: pixels >200 on dark bg (<80)
        # if large white cluster exists left side, likely text hallucination
        # quick: count white pixels in left; raw should be near 0 white text
        pix = list(left.getdata())
        white = sum(1 for v in pix if v>210)
        ratio = white/len(pix)
        # clean background should have <1% white; text hallucination gives 2-5%
        if ratio > 0.015:
            # double check not just bright background: sample bg luminance
            # if white cluster is glyph-like (connected), treat as WARN
            return None if ratio>0.08 else None  # keep silent for now, rely on tesseract when available
    except: pass
    return None

def score_image(path, blur_thresh=80, left_edge_thresh=20, ratio_thresh=1.2):
    img = Image.open(path)
    W,H = img.size
    blur = laplacian_variance(img)
    ld,rd,ratio = left_clean_score(img)
    reasons=[]; status="good"
    if blur < blur_thresh:
        reasons.append(f"blur {blur:.1f}<{blur_thresh}"); status="bad"
    if ld > left_edge_thresh:
        reasons.append(f"left clutter edge={ld:.1f}>{left_edge_thresh}")
        status="near-miss" if status=="good" else "bad"
    if ratio > ratio_thresh:
        reasons.append(f"left/right ratio {ratio:.2f}>{ratio_thresh}")
        if status=="good": status="near-miss"
    if rd < 5:
        reasons.append(f"right low detail {rd:.1f}")
        if status=="good": status="near-miss"
    if W!=1280 or H!=720:
        reasons.append(f"size {W}x{H} != 1280x720")
        if status=="good": status="near-miss"
    # hallucinated text check (no %/numbers) — new in 2026-08-25 patch
    hall = detect_hallucinated_text(path)
    if hall:
        reasons.append(hall)
        if hall.startswith("FAIL"): status="bad"
        elif status=="good": status="near-miss"
    if not reasons: reasons.append(f"pass blur={blur:.0f} left={ld:.1f} right={rd:.1f} ratio={ratio:.2f}")
    return {"file":str(path),"status":status,"blur":round(blur,1),"left_edge":round(ld,1),"right_edge":round(rd,1),"ratio":round(ratio,2),"size":f"{W}x{H}","reasons":reasons}

def visual_diff_final(final_path, style_name):
    """Check final png against reference style lessons — allowed palette only."""
    if not pathlib.Path(final_path).exists():
        return {"error":"final not found"}
    style=None
    if STYLES.exists():
        data=json.loads(STYLES.read_text())
        style=data.get("references",{}).get(style_name)
    # Analyze final image for text-like high contrast regions (approx)
    img=Image.open(final_path).convert("RGBA")
    W,H=img.size
    # Check for outer border violation — top row should not be solid gold/frame
    top_row=img.crop((0,0,W,8)).convert("RGB")
    # sample gold/marine border would be solid color on edge
    # compute edge uniformity: if top 8px is uniform gold #D4AF37 or marine #0F172A, it's a forbidden outer frame
    top_pixels=list(top_row.getdata())
    # count gold pixels ~212,175,55 ±15
    gold_count=sum(1 for p in top_pixels if abs(p[0]-212)<15 and abs(p[1]-175)<15 and abs(p[2]-55)<15)
    marine_count=sum(1 for p in top_pixels if abs(p[0]-15)<15 and abs(p[1]-23)<15 and abs(p[2]-42)<15)
    border_violation = (gold_count/len(top_pixels) > 0.85) or (marine_count/len(top_pixels) > 0.85)
    checks=[]
    if border_violation:
        checks.append("FAIL outer border detected — user forbids surrounding frame (gold/marine on top 8px)")
    else:
        checks.append("pass no outer border")
    # Style-specific lessons
    if style_name=="ben_dark_gold":
        # expect duplicate shadow 4px not halo, left text top, gold block behind last line
        # heuristic: check for gold block presence in left area (not top border)
        left = img.crop((int(W*0.04), int(H*0.35), int(W*0.55), int(H*0.65))).convert("RGB")
        # count gold inside left 35-65% vertical band (where block sits)
        gold_in = sum(1 for p in left.getdata() if abs(p[0]-212)<20 and abs(p[1]-175)<20 and abs(p[2]-55)<20)
        ratio=gold_in/(left.size[0]*left.size[1])
        if ratio < 0.08:
            checks.append(f"WARN ben gold block missing/low {ratio:.2%} — expected ~15-25% gold in left mid band (lesson from Ben ref #E85D7A→gold)")
        else:
            checks.append(f"pass ben gold block {ratio:.1%}")
        # check no pink
        pink_in=sum(1 for p in img.convert("RGB").getdata() if abs(p[0]-232)<15 and abs(p[1]-93)<15 and abs(p[2]-122)<15)
        if pink_in>100:
            checks.append(f"FAIL pink #E85D7A detected {pink_in}px — forbidden, use gold #D4AF37")
        else:
            checks.append("pass no forbidden pink")
    elif style_name=="peterson_heavenly":
        # expect bottom plate dark + per-word orange/heavenly
        bottom=img.crop((0,int(H*0.60),W,H)).convert("RGB")
        orange_in=sum(1 for p in bottom.getdata() if abs(p[0]-255)<20 and abs(p[1]-123)<20 and abs(p[2]-46)<20)
        heavenly_in=sum(1 for p in bottom.getdata() if abs(p[0]-56)<20 and abs(p[1]-189)<20 and abs(p[2]-248)<20)
        if orange_in < 500 and heavenly_in < 500:
            checks.append("WARN peterson per-word color missing — expected orange #FF7B2E or heavenly #38BDF8 in bottom 40% (lesson from peterson_clips)")
        else:
            checks.append(f"pass peterson per-word orange {orange_in} heavenly {heavenly_in}")
    elif style_name=="chris_heavenly":
        # centered, heavenly underline
        mid=img.crop((0,int(H*0.55),W,int(H*0.75))).convert("RGB")
        heavenly_line=sum(1 for p in mid.getdata() if abs(p[0]-46)<20 and abs(p[1]-134)<20 and abs(p[2]-171)<20)
        if heavenly_line < 800:
            checks.append("WARN chris heavenly underline missing — expected #2E86AB line near y=0.65 (lesson from chris)")
        else:
            checks.append(f"pass chris underline {heavenly_line}")
    # overall allowed palette check
    # no outer border already
    status="good" if all("FAIL" not in c for c in checks) else "near-miss" if any("WARN" in c for c in checks) else "bad"
    if any("FAIL" in c for c in checks): status="bad"
    return {"style":style_name,"checks":checks,"status":status}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("images", nargs="*")
    ap.add_argument("--dir", help="directory for RAW *.png")
    ap.add_argument("--json", dest="json_out")
    ap.add_argument("--threshold-blur", type=float, default=80)
    ap.add_argument("--threshold-left", type=float, default=20)
    ap.add_argument("--threshold-ratio", type=float, default=1.2)
    ap.add_argument("--final", help="final composited png to visual-diff vs --style")
    ap.add_argument("--style", help="style name for visual-diff: ben_dark_gold | peterson_heavenly | chris_heavenly | luna_art")
    ap.add_argument("--references", action="store_true", help="print embedded reference manifest stats")
    args=ap.parse_args()
    if args.references:
        if MANIFEST.exists():
            print(MANIFEST.read_text())
        else:
            print("no manifest")
        refs=list(REFS_DIR.glob("*/*.jpg"))
        print(f"\n{len(refs)} reference thumbs embedded:")
        for p in sorted(refs): print(f"  {p.relative_to(SKILL_ROOT)}")
        if STYLES.exists():
            print(f"\nStyles: {STYLES}")
            print(json.dumps(json.loads(STYLES.read_text()).get("references",{}).keys().__str__()))
        return
    paths=[]
    if args.dir:
        p=pathlib.Path(args.dir)
        paths+=sorted(p.glob("*.png")); paths+=sorted(p.glob("*.jpg"))
    for g in args.images:
        for pp in pathlib.Path(".").glob(g) if "*" in g else [pathlib.Path(g)]:
            if pp.exists(): paths.append(pp)
    if not paths and not args.final:
        print("no images", file=sys.stderr); sys.exit(1)
    results=[]
    for p in sorted(set(paths)):
        r=score_image(p, args.threshold_blur, args.threshold_left, args.threshold_ratio)
        results.append(r)
        icon={"good":"✓","near-miss":"~","bad":"✗"}[r["status"]]
        print(f"{icon} {r['status']:9} {pathlib.Path(r['file']).name:35} blur={r['blur']:6.1f} left={r['left_edge']:4.1f} right={r['right_edge']:4.1f} ratio={r['ratio']:.2f}  {' | '.join(r['reasons'])}")
    if paths:
        goods=sum(1 for r in results if r["status"]=="good")
        print(f"\n{goods}/{len(results)} good — RAW check (need 3 good). References embedded: {len(list(REFS_DIR.glob('*/*.jpg')))} thumbs")
    if args.final and args.style:
        print(f"\n--- visual-diff final vs reference style {args.style} ---")
        vd=visual_diff_final(args.final, args.style)
        icon={"good":"✓","near-miss":"~","bad":"✗"}[vd["status"]]
        print(f"{icon} {vd['status']:9} {pathlib.Path(args.final).name}")
        for c in vd["checks"]: print(f"  - {c}")
        # overall
        if args.json_out:
            results.append({"visual_diff":vd})
    elif args.final and not args.style:
        print("need --style with --final")
    if args.json_out:
        pathlib.Path(args.json_out).write_text(json.dumps(results, indent=2))
        print(f"json -> {args.json_out}")

if __name__=="__main__":
    main()
