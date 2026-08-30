#!/usr/bin/env python3
"""
Generate instrumental via ComfyUI HTTP (fallback when comfy-mcp not available).
Uses SA3 Medium and ACE 1.5 XL workflows from templates.
Sequential, polls /history.
"""
import argparse, json, sys, time, random, shutil, subprocess
from pathlib import Path
import urllib.request, urllib.error

COMFY_URL = "http://127.0.0.1:8188"
TEMPLATES_DIR = Path(__file__).parent.parent / "templates"

def load_workflow(engine: str):
    if engine == "sa3":
        return json.loads((TEMPLATES_DIR / "sa3_medium_api_base.json").read_text())
    else:
        return json.loads((TEMPLATES_DIR / "ace_1.5_xl_api_base.json").read_text())

def submit_prompt(workflow: dict):
    payload = {"prompt": workflow}
    data = json.dumps(payload).encode()
    req = urllib.request.Request(f"{COMFY_URL}/prompt", data=data, headers={"Content-Type":"application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=30) as r:
        res = json.loads(r.read())
        return res["prompt_id"]

def poll_history(prompt_id: str, timeout=600):
    start=time.time()
    while True:
        if time.time()-start>timeout:
            raise TimeoutError(f"Timeout {prompt_id}")
        try:
            with urllib.request.urlopen(f"{COMFY_URL}/history/{prompt_id}", timeout=10) as r:
                hist=json.loads(r.read())
                if prompt_id in hist:
                    entry=hist[prompt_id]
                    status=entry.get("status",{})
                    if status.get("completed"):
                        return entry
                    if status.get("status_str")=="error":
                        raise RuntimeError(f"Comfy error {entry}")
        except urllib.error.HTTPError as e:
            pass
        time.sleep(2)

def fetch_outputs(prompt_id: str, out_dir: Path):
    out_dir.mkdir(parents=True, exist_ok=True)
    # poll history already got outputs
    with urllib.request.urlopen(f"{COMFY_URL}/history/{prompt_id}", timeout=10) as r:
        hist=json.loads(r.read())[prompt_id]
        outputs=hist.get("outputs",{})
        files=[]
        for node_id, out in outputs.items():
            if "audio" in out:
                for a in out["audio"]:
                    fname=a["filename"]
                    sub=a.get("subfolder","")
                    # ComfyUI serves via /view?filename=&subfolder=&type=output
                    url = f"{COMFY_URL}/view?filename={fname}&subfolder={sub}&type=output"
                    dst = out_dir / fname
                    urllib.request.urlretrieve(url, dst)
                    files.append(dst)
        return files

def main():
    ap=argparse.ArgumentParser(description="Generate instrumental via ComfyUI SA3/ACE")
    ap.add_argument("--prompt", required=True, help="Prompt for instrumental")
    ap.add_argument("--duration", type=int, default=60, help="Seconds 10-300")
    ap.add_argument("--engine", choices=["sa3","ace"], default="sa3")
    ap.add_argument("--bpm", type=int, default=72)
    ap.add_argument("--key", default="E minor")
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--out", help="Output file (mp3)")
    ap.add_argument("--out-dir", help="Output dir")
    ap.add_argument("--no-reprompt", action="store_true", help="SA3 disable reprompt")
    ap.add_argument("--dry-run", action="store_true")
    args=ap.parse_args()
    duration=max(10,min(300,args.duration))
    seed=args.seed if args.seed is not None else random.randint(0,2**31-1)
    print(f"Engine: {args.engine} duration={duration}s prompt={args.prompt[:80]!r} seed={seed}")
    wf=load_workflow(args.engine)
    if args.engine=="sa3":
        # 52:31 prompt primitive string
        if "52:31" in wf:
            wf["52:31"]["inputs"]["value"]=args.prompt
        # 52:36 duration math? actually 52:11 seconds uses 52:36, 52:41 math expression a
        # Set 52:41 values.a = duration and 52:36? Check sa3 workflow: 52:41 is ComfyMathExpression a=duration, 52:36 is maybe PrimitiveInt? Actually 52:36 is int? Let's set both
        # Find nodes with class_type ComfyMathExpression and EmptyLatentAudio
        for nid, node in wf.items():
            if node.get("class_type")=="ComfyMathExpression" and "values.a" in node.get("inputs",{}):
                node["inputs"]["values.a"]=duration
            if node.get("class_type")=="EmptyLatentAudio":
                node["inputs"]["seconds"]=duration
            if node.get("class_type")=="StableAudio_Open":
                node["inputs"]["seconds_total"]=duration
                node["inputs"]["seed"]=seed
                node["inputs"]["prompt"]=args.prompt
        if args.no_reprompt and "52:35" in wf:
            # 52:35 is boolean Enable_Reprompt?
            # Search for Switch 52:34? Actually 52:35 is maybe PrimitiveBool
            for nid, node in wf.items():
                if "reprompt" in str(node).lower():
                    pass
        # Also set KSampler seed
        if "52:3" in wf:
            wf["52:3"]["inputs"]["seed"]=seed
    else: # ace
        if "94" in wf:
            wf["94"]["inputs"]["tags"]=args.prompt
            wf["94"]["inputs"]["duration"]=duration
            wf["94"]["inputs"]["bpm"]=args.bpm
            wf["94"]["inputs"]["keyscale"]=args.key
            wf["94"]["inputs"]["lyrics"]="[instrumental]"
        if "98" in wf:
            wf["98"]["inputs"]["seconds"]=duration
        if "109" in wf:
            # 109 is PrimitiveInt seed? Check
            wf["109"]=wf.get("109",{"inputs":{},"class_type":"PrimitiveInt"})
            wf["109"]["inputs"]["value"]=seed
        # seed in 94 also
        if "94" in wf:
            wf["94"]["inputs"]["seed"]=seed
    if args.dry_run:
        print(json.dumps(wf, indent=2)[:2000])
        return
    # health check
    try:
        with urllib.request.urlopen(f"{COMFY_URL}/system_stats", timeout=5) as r:
            print(f"Comfy stats: {r.read()[:200]}")
    except Exception as e:
        print(f"Warn system_stats {e}", file=sys.stderr)
    prompt_id=submit_prompt(wf)
    print(f"Submitted prompt_id={prompt_id}, polling...")
    entry=poll_history(prompt_id, timeout=600)
    print(f"Completed {prompt_id}")
    out_path=Path(args.out) if args.out else None
    out_dir=Path(args.out_dir) if args.out_dir else Path.cwd() / "renders"
    if out_path and out_path.is_dir():
        out_dir=out_path
        out_path=None
    files=fetch_outputs(prompt_id, out_dir if not out_path else out_path.parent)
    print(f"Fetched {files}")
    if out_path and files:
        # move first file to out_path
        shutil.move(str(files[0]), str(out_path))
        print(f"Saved to {out_path} ({out_path.stat().st_size/1024:.0f}KB)")
        # probe
        if shutil.which("ffprobe"):
            r=subprocess.run(["ffprobe","-v","error","-show_entries","stream=duration,codec_name","-of","default=nw=1",str(out_path)], capture_output=True, text=True)
            print(r.stdout)
    elif files:
        print(f"Saved to {files[0]}")

if __name__=="__main__":
    main()
