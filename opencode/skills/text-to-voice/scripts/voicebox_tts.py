#!/usr/bin/env python3
"""
Voicebox TTS chunked audiobook generator — sequential only.
Uses REST at http://0.0.0.0:17493 (preferred). MCP optional.
"""
import argparse, json, re, sys, time, urllib.request, urllib.error, subprocess, shutil
from pathlib import Path
VOICEBOX_API = "http://127.0.0.1:17493"
DATA_DIR = Path("/home/dennis/work/voicebox/data/generations")
DEFAULT_MAX_CHUNK = 700
def resolve_profile(name_or_id: str):
    url = f"{VOICEBOX_API}/profiles"
    with urllib.request.urlopen(url, timeout=10) as r:
        profiles = json.loads(r.read())
    for p in profiles:
        if p["id"] == name_or_id or p["name"] == name_or_id:
            return p["id"], p["name"], p["language"]
    lower = name_or_id.lower()
    for p in profiles:
        if p["name"].lower() == lower:
            return p["id"], p["name"], p["language"]
    raise SystemExit(f"Profile not found: {name_or_id}. Available: {', '.join(p['name'] for p in profiles[:10])}")
def split_sentences(text: str, max_chars: int = DEFAULT_MAX_CHUNK):
    text = text.strip()
    if not text: return []
    if len(text) <= max_chars:
        return [text]
    paragraphs = re.split(r'\n\s*\n', text)
    chunks = []
    for para in paragraphs:
        para = para.strip()
        if not para: continue
        if len(para) <= max_chars:
            chunks.append(para)
            continue
        sentences = re.split(r'(?<=[.!?])\s+(?=[A-ZÄÖÜ\"\'\(\[])', para)
        if len(sentences) == 1:
            sentences = re.split(r'\n', para)
        cur = ""
        for sent in sentences:
            sent = sent.strip()
            if not sent: continue
            if len(cur) + len(sent) + 1 <= max_chars:
                cur = (cur + " " + sent).strip() if cur else sent
            else:
                if cur: chunks.append(cur)
                if len(sent) > max_chars:
                    words = sent.split()
                    wcur = ""
                    for w in words:
                        if len(wcur) + len(w) + 1 <= max_chars:
                            wcur = (wcur + " " + w).strip() if wcur else w
                        else:
                            if wcur: chunks.append(wcur)
                            if len(w) > max_chars:
                                for i in range(0, len(w), max_chars):
                                    chunks.append(w[i:i+max_chars])
                                wcur = ""
                            else:
                                wcur = w
                    if wcur: cur = wcur
                    else: cur = ""
                else:
                    cur = sent
        if cur: chunks.append(cur)
    merged = []
    for c in chunks:
        if merged and len(c) < 100 and len(merged[-1]) + len(c) + 1 < max_chars:
            merged[-1] = merged[-1] + " " + c
        else:
            merged.append(c)
    return [c for c in merged if c.strip()]
def post_generate(profile_id: str, text: str, language: str, max_chunk_chars: int = 800):
    payload = {"profile_id": profile_id, "text": text, "language": language, "max_chunk_chars": max_chunk_chars, "crossfade_ms": 50, "normalize": True}
    data = json.dumps(payload).encode()
    req = urllib.request.Request(f"{VOICEBOX_API}/generate", data=data, headers={"Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=30) as r:
        body = json.loads(r.read())
        return body["id"]
def poll_status(gen_id: str, timeout=300):
    url = f"{VOICEBOX_API}/generate/{gen_id}/status"
    start = time.time()
    last = None
    while True:
        if time.time() - start > timeout:
            raise TimeoutError(f"Generation {gen_id} timed out after {timeout}s")
        try:
            req = urllib.request.Request(url, headers={"Accept": "text/event-stream"})
            with urllib.request.urlopen(req, timeout=10) as r:
                raw = r.read().decode(errors="ignore")
        except urllib.error.HTTPError:
            time.sleep(0.5)
            continue
        lines = [l for l in raw.splitlines() if l.strip().startswith("data:")]
        if not lines:
            time.sleep(0.5)
            continue
        try:
            last = json.loads(lines[-1][5:].strip())
        except:
            time.sleep(0.5)
            continue
        status = last.get("status")
        if status == "completed": return last
        if status == "failed": raise RuntimeError(f"Generation {gen_id} failed: {last.get('error')}")
        time.sleep(0.5)
def main():
    ap = argparse.ArgumentParser(description="Voicebox sequential chunked TTS -> audiobook")
    grp = ap.add_mutually_exclusive_group(required=True)
    grp.add_argument("--input", help="Input text file (txt/md)")
    grp.add_argument("--text", help="Direct text string")
    grp.add_argument("--stdin", action="store_true", help="Read from stdin")
    ap.add_argument("--out", help="Output wav path (default: ./<input_stem>.wav)")
    ap.add_argument("--out-dir", help="Output directory")
    ap.add_argument("--voice", default="the_narrator_en", help="Voice profile name/id (default: the_narrator_en)")
    ap.add_argument("--lang", help="Language override")
    ap.add_argument("--max-chunk", type=int, default=DEFAULT_MAX_CHUNK, help=f"Max chars per chunk (default {DEFAULT_MAX_CHUNK})")
    ap.add_argument("--no-concat", action="store_true", help="Keep chunk wavs, don't concat")
    ap.add_argument("--keep-chunks", action="store_true", help="Keep chunk wavs")
    ap.add_argument("--dry-run", action="store_true", help="Only split and show chunks")
    args = ap.parse_args()
    if args.input:
        p = Path(args.input)
        if not p.exists(): sys.exit(f"Input not found: {p}")
        text = p.read_text(encoding="utf-8", errors="ignore")
        stem = p.stem
    elif args.text:
        text = args.text
        stem = "output"
    else:
        text = sys.stdin.read()
        stem = "output"
    if not text.strip(): sys.exit("Empty input text")
    profile_id, profile_name, profile_lang = resolve_profile(args.voice)
    language = args.lang or profile_lang or "en"
    max_chunk = max(100, min(5000, args.max_chunk))
    chunks = split_sentences(text, max_chars=max_chunk)
    print(f"Profile: {profile_name} ({profile_id}) lang={language}")
    print(f"Input: {len(text)} chars -> {len(chunks)} chunks (max {max_chunk})")
    for i, c in enumerate(chunks[:3]):
        print(f"  chunk {i+1}: {len(c)} chars: {c[:80]!r}...")
    if len(chunks) > 3: print(f"  ... +{len(chunks)-3} more")
    if args.dry_run:
        for i, c in enumerate(chunks):
            print(f"\n--- CHUNK {i+1}/{len(chunks)} ({len(c)} chars) ---\n{c}\n")
        return
    if args.out:
        out_path = Path(args.out)
    elif args.out_dir:
        out_path = Path(args.out_dir) / f"{stem}.wav"
    else:
        out_path = Path.cwd() / f"{stem}.wav"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    chunk_dir = out_path.parent / f".tts_chunks_{out_path.stem}"
    chunk_dir.mkdir(parents=True, exist_ok=True)
    try:
        with urllib.request.urlopen(f"{VOICEBOX_API}/health", timeout=5) as r:
            h = json.loads(r.read())
            if h.get("status") != "healthy":
                print(f"Warn: health {h}", file=sys.stderr)
    except Exception as e:
        sys.exit(f"Voicebox not reachable at {VOICEBOX_API}: {e}")
    if not shutil.which("ffmpeg"):
        print("Warn: ffmpeg not found - concat will fail, install via pacman -S ffmpeg", file=sys.stderr)
    chunk_wavs = []
    for idx, chunk_text in enumerate(chunks):
        print(f"\n[{idx+1}/{len(chunks)}] Generating {len(chunk_text)} chars...")
        gen_id = post_generate(profile_id, chunk_text, language, max_chunk_chars=800)
        print(f"  -> id {gen_id}, polling...")
        result = poll_status(gen_id, timeout=600)
        audio_rel = result.get("audio_path")
        if not audio_rel:
            try:
                with urllib.request.urlopen(f"{VOICEBOX_API}/history?limit=100", timeout=10) as r:
                    hist = json.loads(r.read())
                    for item in hist.get("items", []):
                        if item["id"] == gen_id:
                            audio_rel = item.get("audio_path")
                            break
            except Exception:
                pass
        if not audio_rel: audio_rel = f"generations/{gen_id}.wav"
        src = DATA_DIR / Path(audio_rel).name
        if not src.exists():
            alt = Path("/home/dennis/work/voicebox/data") / audio_rel
            if alt.exists(): src = alt
        if not src.exists():
            candidates = list(DATA_DIR.glob(f"{gen_id}*.wav"))
            if candidates: src = candidates[0]
            else: raise FileNotFoundError(f"Audio for {gen_id} not found (expected {src})")
        dst = chunk_dir / f"chunk_{idx:04d}.wav"
        shutil.copy2(src, dst)
        dur = result.get("duration") or "?"
        print(f"  ✓ {dst.name} duration {dur}s")
        chunk_wavs.append(dst)
        time.sleep(0.2)
    if args.no_concat:
        print(f"\nDone: {len(chunk_wavs)} chunk files in {chunk_dir}")
        return
    if len(chunk_wavs) == 1:
        shutil.copy2(chunk_wavs[0], out_path)
        print(f"\nSingle chunk -> copied to {out_path}")
    else:
        list_file = chunk_dir / "concat.txt"
        with open(list_file, "w") as f:
            for w in chunk_wavs:
                f.write(f"file '{w.resolve()}'\n")
        cmd_copy = ["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", str(list_file), "-c", "copy", str(out_path)]
        print(f"\nConcatenating {len(chunk_wavs)} chunks -> {out_path} ...")
        result = subprocess.run(cmd_copy, capture_output=True, text=True)
        if result.returncode != 0 or not out_path.exists() or out_path.stat().st_size == 0:
            print(f"Copy concat failed, retry re-encode: {result.stderr[:500]}", file=sys.stderr)
            cmd_enc = ["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", str(list_file), str(out_path)]
            result2 = subprocess.run(cmd_enc, capture_output=True, text=True)
            if result2.returncode != 0:
                print(result2.stderr, file=sys.stderr)
                sys.exit(f"ffmpeg concat failed")
        print(f"✓ Final: {out_path} ({out_path.stat().st_size/1024/1024:.2f} MB, {len(chunk_wavs)} chunks)")
    if not args.keep_chunks:
        shutil.rmtree(chunk_dir, ignore_errors=True)
        print(f"Cleaned chunk dir {chunk_dir} (use --keep-chunks to retain)")
    else:
        print(f"Chunks retained in {chunk_dir}")
if __name__ == "__main__":
    main()
