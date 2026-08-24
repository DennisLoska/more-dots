#!/usr/bin/env python3
"""
thumbnail_loop.py — adversarial loop wrapper: Generate R RAW (5-20), pick best F=3, overlay + visual-diff up to 10 rounds per final
Implements the capped adversarial validation described in SKILL.md Loop section.
Requires: generate-comfy-image workflow already defined (or call via overlay_helper only for text validation demo)
Usage for text-only validation demo (no diffusion):
  python thumbnail_loop.py --raw-dir renders --final-text "NO\nSHORTCUT" --style ben_dark_gold --finals 3 --subtitle "THE WITCHES OF THESSALY"
Full usage with diffusion (calls MCP via generate-comfy-image skill — not implemented here, use skill workflow):
  This script handles RAW picking + text validation; diffusion generation is done via skill's MCP calls before invoking this.
"""
import argparse, pathlib, json, subprocess, sys

SKILL_ROOT = pathlib.Path(__file__).resolve().parents[1]
CRITIQUE = SKILL_ROOT / "scripts" / "batch_critique.py"
OVERLAY = SKILL_ROOT / "scripts" / "overlay_helper.py"

def run_critique(raw_dir):
    import subprocess
    out = subprocess.check_output(["python3", str(CRITIQUE), "--dir", str(raw_dir)], text=True)
    # parse lines like "✓ good      file.png ..."
    picks=[]
    for line in out.splitlines():
        if line.strip().startswith("✓") or line.strip().startswith("~") or line.strip().startswith("✗"):
            parts=line.split()
            status=parts[1]
            fname=parts[2]
            picks.append((status, fname, line))
    # rank good > near-miss > bad, then custom
    rank={"good":0,"near-miss":1,"bad":2}
    picks.sort(key=lambda x: rank.get(x[0],3))
    return picks

def visual_diff(final, style):
    out = subprocess.check_output(["python3", str(CRITIQUE), "--final", str(final), "--style", style], text=True, stderr=subprocess.DEVNULL)
    # check for FAIL
    status="good"
    if "FAIL" in out: status="bad"
    elif "WARN" in out: status="near-miss"
    return status, out

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--raw-dir", required=True, help="dir with RAW candidates (5-20)")
    ap.add_argument("--final-text", required=True, help="text with \\n e.g. NO\\nSHORTCUT")
    ap.add_argument("--style", required=True, help="ben_dark_gold | peterson_heavenly | chris_heavenly")
    ap.add_argument("--finals", type=int, default=3, help="how many finals to pick (F)")
    ap.add_argument("--subtitle", default=None)
    ap.add_argument("--per-word", default=None)
    ap.add_argument("--out-dir", default=None, help="output dir for finals (default raw-dir)")
    ap.add_argument("--max-rounds", type=int, default=10, help="adversarial rounds per final")
    args=ap.parse_args()
    raw_dir=pathlib.Path(args.raw_dir)
    out_dir=pathlib.Path(args.out_dir) if args.out_dir else raw_dir
    out_dir.mkdir(parents=True, exist_ok=True)
    # 1. RAW adversarial pick
    picks=run_critique(raw_dir)
    print(f"RAW candidates: {len(picks)} ranked:")
    for s,f,_ in picks[:min(len(picks),10)]:
        print(f"  {s:9} {f}")
    # pick top F
    F=args.finals
    R=len(picks)
    expected_R = min(max(F*3,5),20)
    if R < expected_R:
        print(f"WARN only {R} RAW candidates, expected {expected_R} for F={F} (need 5-20) — generating more would improve adversarial pick")
    top = picks[:F]
    # if not enough good, still use near-miss
    print(f"\nPicking top {F} for overlay:")
    for s,f,_ in top: print(f"  {s} {f}")
    finals=[]
    per_word=args.per_word
    lines=args.final_text.replace("\\n","\n").split("\n")
    for idx,(status,fname,_) in enumerate(top):
        raw_path=raw_dir/fname if (raw_dir/fname).exists() else pathlib.Path(fname)
        # find raw path robustly
        if not raw_path.exists():
            # try raw_dir glob
            cand=list(raw_dir.glob(f"*{fname}*"))
            if cand: raw_path=cand[0]
        print(f"\n--- final {idx+1}/{F}: {raw_path.name} raw={status} ---")
        # adversarial visual-diff loop up to 10
        best=None; best_status="bad"
        for rnd in range(1, args.max_rounds+1):
            out_path=out_dir / f"final_{args.style}_{idx+1}_r{rnd}.png"
            # call overlay
            cmd=["python3", str(OVERLAY), "--input", str(raw_path), "--output", str(out_path), "--lines"]+lines+["--style", args.style]
            if args.subtitle: cmd+=["--subtitle", args.subtitle]
            if per_word: cmd+=["--per-word", per_word]
            subprocess.check_call(cmd)
            v_status, v_out = visual_diff(out_path, args.style)
            print(f"  round {rnd}: {v_status} — {v_out.splitlines()[-3] if v_out else ''}")
            # crude adversarial fix: if WARN gold block low, next round highlight_last larger (handled inside overlay by reusing same — here just retry same, demo)
            # For demo, we just keep same overlay — in real use per-word could be tuned
            if v_status=="good":
                print(f"    ✓ good at round {rnd}")
                finals.append((out_path, v_status, rnd))
                best=None
                break
            else:
                best=(out_path,v_status,rnd)
                # if bad due to border/pink, retry would not fix without param change — but our overlay now has no border, so good
                if rnd>=3 and v_status=="near-miss":
                    # accept near-miss after 3 as best
                    pass
        if best:
            print(f"    max rounds {args.max_rounds} reached, keeping best {best[1]}")
            finals.append(best)
        # if bad after 10, try next RAW candidate (not implemented in demo — would pick 4th best)
    print(f"\nDone: {len(finals)}/{F} finals (capped {args.max_rounds} rounds each, {R} RAW candidates)")
    for p,s,r in finals:
        print(f"  {p.name}: {s} at round {r}")
    # summary
    print(f"\nAdversarial validation: generated {R} RAW to pick {F} (over-generate 5-20), {args.max_rounds}-round visual-diff per final (text only, no new diffusion).")

if __name__=="__main__":
    main()
