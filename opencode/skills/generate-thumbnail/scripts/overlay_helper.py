#!/usr/bin/env python3
"""
overlay_helper.py v2 — visual-diff driven, allowed palette only (dark/black/gold/marine/violet/orange/yellow)
Fixes from inspo diff (Ben/Chris/Peterson):
- Thin duplicate offset shadow (4px) not halo stroke 10/12
- Larger scale 1.35x, top y=8% Ben, bottom y=62% Peterson, center y=30% Chris
- Per-word color + italic (orange heavenly violet gold)
- Gold block behind last line (not pink), outer gold/marine border, white rule/underline, quote marks
Usage:
  python overlay_helper.py --input raw.png --output final.png --lines "NO" "SHORTCUT" --style ben_dark_gold --subtitle "THE WITCHES OF THESSALY"
  python overlay_helper.py --input raw.png --output final.png --lines "WHY" "PARADISE WOULD BORE YOU" --style peterson_heavenly --per-word "PARADISE:orange,BORE:orange,DEATH:heavenly_italic"
  python overlay_helper.py --input raw.png --output final.png --text '"BIOLOGY HAS NO LIMITS."' --style chris_heavenly
"""
import argparse, pathlib, json, re
from PIL import Image, ImageDraw, ImageFont, ImageStat

SKILL_ROOT = pathlib.Path(__file__).resolve().parents[1]
FONTS_DIR = SKILL_ROOT / "fonts"
STYLES_JSON = SKILL_ROOT / "styles" / "reference_styles.json"
FALLBACK_FONTS_DIR = pathlib.Path.home() / ".config/opencode/skills/generate-comfy-image/fonts"

SYSTEM_FONTS = ["/usr/share/fonts/liberation/LiberationSans-Bold.ttf"]

PRIORITY_FONTS = [
    FONTS_DIR / "Anton-Regular.ttf",
    FONTS_DIR / "Oswald-Variable.ttf",
    FONTS_DIR / "BebasNeue-Regular.ttf",
    FONTS_DIR / "Montserrat-Variable.ttf",
    FALLBACK_FONTS_DIR / "Anton-Regular.ttf",
]

PALETTE = {
    "white": (255,255,255), "black": (10,10,10), "gold": (212,175,55), "old_gold": (184,148,31),
    "yellow": (255,214,0), "orange": (255,123,46), "heavenly": (46,134,171), "sky": (14,165,233),
    "marine": (15,23,42), "dark": (10,23,42), "violet": (109,40,217), "deep_violet": (20,0,40),
    "light_blue": (56,189,248), "cyan": (14,165,233),
}

def parse_hex(s):
    m=re.search(r"#([0-9a-fA-F]{6})", s or "")
    if m: return tuple(int(m.group(1)[i:i+2],16) for i in (0,2,4))
    return None

def load_style(name):
    if not name or not STYLES_JSON.exists(): return None
    data=json.loads(STYLES_JSON.read_text())
    if name in data.get("references", {}): return data["references"][name]
    if name=="base": return data.get("base",{})
    return None

def find_font(preferred=None, style=None):
    if style and "head_font" in style.get("typography", {}):
        cand=FONTS_DIR / style["typography"]["head_font"]
        if cand.exists():
            try: ImageFont.truetype(str(cand),40); return str(cand)
            except: pass
    if preferred:
        for base in [FONTS_DIR, FALLBACK_FONTS_DIR, pathlib.Path(".")]:
            p=pathlib.Path(preferred)
            if p.exists(): return str(p)
            cand=base / preferred if not str(preferred).endswith(".ttf") else base / preferred
            if cand.exists(): return str(cand)
    for p in PRIORITY_FONTS:
        if p.exists():
            try: ImageFont.truetype(str(p),40); return str(p)
            except: continue
    for p in SYSTEM_FONTS:
        if pathlib.Path(p).exists(): return p
    return None

def sample_left_luminance(img, left_ratio=0.4):
    left=img.crop((0,0,int(img.size[0]*left_ratio), img.size[1])).convert("L")
    return ImageStat.Stat(left).mean[0]

def hex_to_rgb(h): return parse_hex(h) or (0,0,0)

def draw_text_duplicate(draw, xy, text, font, fill, shadow_offset=4):
    # thin duplicate shadow first
    draw.text((xy[0]+shadow_offset, xy[1]+shadow_offset), text, font=font, fill=(0,0,0,220))
    # main
    draw.text(xy, text, font=font, fill=fill)

def add_overlay(input_path, output_path, lines, subtitle=None, font_path=None, style_name=None, border=None, per_word=None, highlight_last=None, centered=False):
    style=load_style(style_name) if style_name else None
    img=Image.open(input_path).convert("RGBA")
    W,H=img.size
    # NO outer border — user forbids surrounding frame. Only if explicitly --border passed
    border_color=None
    border_w=0
    if border:
        parts=border.split(",")
        bc=parts[0].strip()
        bw=int(parts[1]) if len(parts)>1 else 8
        if bc.startswith("#"): border_color=hex_to_rgb(bc)
        else: border_color=PALETTE.get(bc.lower(), (212,175,55))
        border_w=bw
    # style outer_border intentionally ignored — no surrounding frame per user request
    # create canvas with border
    if border_color and border_w>0:
        bg=Image.new("RGBA", (W,H), border_color+(255,))
        inner=img
        overlay_base=Image.new("RGBA", (W,H), (0,0,0,0))
        # inset image
        img_inner=inner.crop((0,0,W-2*border_w, H-2*border_w)) if False else inner
        # paste inner with inset
        bg.paste(img, (border_w, border_w))
        # for drawing, we will draw on overlay with offset
        img=bg
        draw_offset=border_w
        # update W,H stays same, but drawable area inset
        overlay=Image.new("RGBA", (W,H), (0,0,0,0))
        draw=ImageDraw.Draw(overlay)
    else:
        draw_offset=0
        overlay=Image.new("RGBA", (W,H), (0,0,0,0))
        draw=ImageDraw.Draw(overlay)

    # style typography
    scale_head = style.get("typography", {}).get("scale_head", 1.35) if style else 1.35
    # font
    fp=find_font(font_path, style)
    if not fp: raise FileNotFoundError("no font")
    is_anton="Anton" in fp

    scale=W/1280
    # sizes: Ben needs larger last line gold block, Peterson needs hierarchical
    base_no = int(140*scale*scale_head)
    base_short = int(105*scale*scale_head)
    if not is_anton:
        # Bebas tall needs smaller to match Anton impact
        base_no=int(base_no*0.92); base_short=int(base_short*0.92)

    # positioning from style
    y_pos =  int(H*0.08) if style_name in ["ben_dark_gold"] else int(H*0.62) if style_name in ["peterson_heavenly"] else int(H*0.32) if style_name in ["chris_heavenly"] else int(H*0.08)
    x_base = int(W*0.04) if not style_name=="chris_heavenly" else int(W*0.5)
    # per-word map
    pw={}
    if per_word:
        for pair in per_word.split(","):
            if ":" in pair:
                w,c=pair.split(":",1)
                pw[w.strip().upper()]=c.strip().lower()
    lum=sample_left_luminance(img)
    # centered flag from style
    if style and style.get("typography", {}).get("centered"): centered=True
    if style_name=="chris_heavenly": centered=True

    # highlight last logic
    hl_color = highlight_last
    if not hl_color and style and "color" in style:
        hb=style["color"].get("highlight_block")
        if hb: hl_color=hb
    if hl_color and hl_color.startswith("#"): hl_rgb=hex_to_rgb(hl_color)
    elif hl_color and hl_color.lower() in PALETTE: hl_rgb=PALETTE[hl_color.lower()]
    else: hl_rgb=PALETTE["gold"] if style_name=="ben_dark_gold" else None

    y=y_pos
    shadow_offset=4
    # draw plate for peterson behind bottom text area
    if style_name=="peterson_heavenly":
        # estimate plate height: 3 lines + rules
        plate_h=int(260*scale)
        plate_y=y_pos-16
        draw.rectangle([int(W*0.02), plate_y, int(W*0.74), plate_y+plate_h], fill=(0,0,0,180))
    last_line_idx=len(lines)-1
    for i, line in enumerate(lines):
        is_last = i==last_line_idx and hl_rgb and style_name=="ben_dark_gold"
        # font size per line: first line slightly smaller in Ben, last larger; Peterson middle large
        if style_name=="ben_dark_gold":
            fsize = int(125*scale*scale_head) if i==0 else int(155*scale*scale_head) if is_last else int(125*scale*scale_head)
        elif style_name=="peterson_heavenly":
            fsize = int(52*scale*scale_head) if i==0 else int(82*scale*scale_head) if i==1 else int(80*scale*scale_head)
        elif style_name=="chris_heavenly":
            fsize = int(78*scale*scale_head) if i==0 else int(96*scale*scale_head) if i==1 else int(92*scale*scale_head)
            # centered quote: limit width
        else:
            fsize = base_no if i==0 else base_short
        font=ImageFont.truetype(fp, fsize)
        # for italic per-word we need separate handling — draw word by word
        words=line.split()
        # measure whole line for block/centering
        full_w = draw.textbbox((0,0), line, font=font)[2]
        # highlight block for last line Ben
        if is_last:
            # block full width left 58% + padding 12
            block_w = min(full_w+28, int(W*0.52)) if style_name=="ben_dark_gold" else full_w+24
            # need to compute text height
            tb = draw.textbbox((0,0), line, font=font)
            th = tb[3]-tb[1]
            bx = x_base if not centered else int((W-block_w)/2)
            # block y with padding 8 top 10 bottom
            by = y-10
            bh = th+26
            # draw gold block
            draw.rectangle([bx, by, bx+block_w, by+bh], fill=hl_rgb+(255,))
            # ensure text centered inside block? Ben left aligned inside block
            tx = bx+12 if not centered else int(((bx+block_w+bx)/2) - full_w/2)
            # per-word inside block but text color black on gold for contrast (allowed)
            # use black fill on gold
            fill_block = (255,255,255,255)
            # draw duplicate shadow inside block? use dark grey offset
            draw.text((tx+shadow_offset, y+shadow_offset), line, font=font, fill=(0,0,0,160))
            draw.text((tx, y), line, font=font, fill=fill_block)
            # white brush underline under block (4px grunge)
            uy = by+bh+8
            # simple white brush line 70% of block width
            brush_w = int(block_w*0.85)
            draw.rectangle([bx+6, uy, bx+6+brush_w, uy+4], fill=(255,255,255,255))
            y = by+bh+14
            continue
        # normal line: per-word coloring
        if not centered:
            x = x_base
        else:
            x = int(W*0.06) if style_name=="chris_heavenly" else int((W - full_w)/2)
        # draw word by word with different fill for per-word highlights
        cur_x = x
        # need to know space width
        space_w = draw.textbbox((0,0), " ", font=font)[2]
        for wi, w in enumerate(words):
            key=w.strip('“”"!.,').upper()
            col_name=pw.get(key)
            if col_name:
                if "orange" in col_name: fill=PALETTE["orange"]+(255,)
                elif "heavenly" in col_name or "marine" in col_name or "blue" in col_name: fill=PALETTE["heavenly"]+(255,)
                elif "gold" in col_name: fill=PALETTE["gold"]+(255,)
                elif "violet" in col_name: fill=PALETTE["violet"]+(255,)
                elif "yellow" in col_name: fill=PALETTE["yellow"]+(255,)
                elif "white" in col_name: fill=(255,255,255,255)
                else: fill=(255,255,255,255)
                # italic? try to fake with skew? PIL no italic, use same font but note
                is_italic="italic" in col_name
                # for italic we could use same but could load italic fallback if exists — skip, just color
            else:
                # Peterson default: first line white, second line white+orange mix via per_word, else white
                fill=(255,255,255,255)
            # draw duplicate offset
            draw.text((cur_x+shadow_offset, y+shadow_offset), w, font=font, fill=(0,0,0,180))
            draw.text((cur_x, y), w, font=font, fill=fill)
            w_width = draw.textbbox((0,0), w, font=font)[2]
            cur_x += w_width + space_w
        # measure line height
        lh = draw.textbbox((x,y), line, font=font)[3]-y
        # underline for Chris between lines
        if style_name in ["peterson_heavenly"] and i==0:
            # white rule 2px between line1 and line2
            rule_y = y+lh+6
            draw.rectangle([x, rule_y, x+int(W*0.52), rule_y+2], fill=(255,255,255,255))
            y = rule_y+8
        elif style_name in ["chris_heavenly"] and i==0:
            # cyan underline under line1? Actually after line1 white, underline cyan 3px under LIMITS later — handle after
            y += lh+8
        else:
            y += lh+10

    # Chris underline + attribution
    if style_name=="chris_heavenly":
        # cyan underline 3px centered
        uw=int(W*0.45); ux=int((W-uw)/2)
        draw.rectangle([ux, y, ux+uw, y+3], fill=PALETTE["heavenly"]+(255,))
        y+=12
        # attribution small white centered if subtitle provided
        if subtitle:
            # use smaller font
            sub_font=ImageFont.truetype(fp, int(28*scale))
            sub_w=draw.textbbox((0,0), subtitle, font=sub_font)[2]
            sx=int((W-sub_w)/2)
            draw.text((sx+2, y+2), subtitle, font=sub_font, fill=(0,0,0,180))
            draw.text((sx, y), subtitle, font=sub_font, fill=(255,255,255,255))
    elif subtitle and style_name!="chris_heavenly":
        # normal subtitle black bar
        sub_font=ImageFont.truetype(fp, int(26*scale))
        sub_w=draw.textbbox((0,0), subtitle, font=sub_font)[2]
        sh=draw.textbbox((0,0), subtitle, font=sub_font)[3]
        sw=sub_w+24; sh+=12
        max_sw=int(W*0.42)
        sw=min(sw, max_sw)
        sx=x_base; sy=y+6
        if style_name=="peterson_heavenly":
            sy=y+10
        draw.rectangle([sx, sy-2, sx+sw, sy+sh], fill=(0,0,0,170))
        draw.text((sx+12, sy), subtitle, font=sub_font, fill=(255,255,255,255))

    out=Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
    pathlib.Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    out.save(output_path, quality=95)
    print(f"saved {output_path} style={style_name} font={pathlib.Path(fp).name} border={border_w} y0={y_pos} words={pw}")

if __name__=="__main__":
    ap=argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--output", required=True)
    ap.add_argument("--text", help="text with \\n")
    ap.add_argument("--lines", nargs="*", help="lines")
    ap.add_argument("--subtitle", default=None)
    ap.add_argument("--font", default=None)
    ap.add_argument("--style", default=None, help="ben_dark_gold | peterson_heavenly | chris_heavenly | luna_art | base")
    ap.add_argument("--border", default=None, help="color,width e.g. gold,8 or #D4AF37,8")
    ap.add_argument("--per-word", default=None, help="WORD:color,WORD2:orange etc. colors: orange,heavenly,gold,violet,yellow,white (add _italic for blue italic)")
    ap.add_argument("--highlight-last", default=None, help="gold/violet/marine/black hex or name for Ben block")
    args=ap.parse_args()
    if args.lines: lines=args.lines
    elif args.text: lines=args.text.replace("\\n","\n").split("\n")
    else: ap.error("need --text or --lines")
    add_overlay(args.input, args.output, lines, args.subtitle, args.font, args.style, args.border, args.per_word, args.highlight_last)

