---
name: image-edit
description: Fast pragmatic image editing - routes between magick CLI (geometric/format ops) and Qwen Image Edit via comfy-mcp (semantic/generative edits). Use when user wants edit image, replace object, restyle, resize, crop, rotate, convert format.
---

# image-edit

Two engines, pick by task.

## Router

| Task | Engine | Why |
|------|--------|-----|
| resize, crop, rotate, flip, format convert, compress, strip metadata | `magick` | instant, no GPU |
| color adjust, blur, sharpen (simple) | `magick` | instant |
| replace object/material, restyle, instruction edit, inpaint, add/remove element | Qwen Image Edit via `comfy-mcp` | generative |

When doubt: magick first. If magick can't do it semantically -> Qwen.

## Engine A: magick (simple ops)

No ComfyUI needed. Direct CLI.

```bash
magick input.jpg -resize 50% output.jpg
magick input.png -crop 800x600+0+0 +repage output.png
magick input.jpg -rotate 90 output.jpg
magick input.png -quality 80 output.webp
magick input.jpg -colorspace Gray output.jpg
magick input.jpg -blur 0x4 output.jpg
```

Batch: loop over files, sequential. Keep originals until output verified.

## Engine B: Qwen Image Edit (semantic)

Via `comfy-mcp` only. Never bash into ComfyUI dirs.

### Models (RTX 5090 fast path = fp8 + lightning)

| file | HF URL | dest |
|------|--------|------|
| `qwen_image_edit_2509_fp8_e4m3fn.safetensors` | `https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_2509_fp8_e4m3fn.safetensors` | `models/diffusion_models/` |
| `Qwen-Image-Edit-2509-Lightning-4steps-V1.0-bf16.safetensors` | `https://huggingface.co/lightx2v/Qwen-Image-Lightning/resolve/main/Qwen-Image-Edit-2509/Qwen-Image-Edit-2509-Lightning-4steps-V1.0-bf16.safetensors` | `models/loras/` |
| `qwen_image_edit_2511_fp8_e4m3fn.safetensors` | `https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_2511_fp8_e4m3fn.safetensors` (alt 2509) | `models/diffusion_models/` |
| `qwen_2.5_vl_7b_fp8_scaled.safetensors` | `https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors` | `models/text_encoders/` |
| `qwen_image_vae.safetensors` | `https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors` | `models/vae/` |

5090 fp8 path needs 2509/2511 fp8 + lightning + vl 7b fp8 + vae. Local already has `qwen_2.5_vl_7b_fp8_scaled` + `qwen_image_2512` family - check `search_models(folder="text_encoders")` + `search_models(folder="vae")`.

### Setup (ask before downloading - files are GBs)

```js
// 1. Check
server_info() // running true, RTX 5090 32GB
search_models(folder="diffusion_models") // check qwen_image_edit present?
search_models(folder="loras") // check lightning lora present?

// 2. If missing, ask user then (2509 is universal, 2511 alt for material):
download_model(url="https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_2509_fp8_e4m3fn.safetensors", relative_path="models/diffusion_models", filename="qwen_image_edit_2509_fp8_e4m3fn.safetensors")
download_model(url="https://huggingface.co/lightx2v/Qwen-Image-Lightning/resolve/main/Qwen-Image-Edit-2509/Qwen-Image-Edit-2509-Lightning-4steps-V1.0-bf16.safetensors", relative_path="models/loras", filename="Qwen-Image-Edit-2509-Lightning-4steps-V1.0-bf16.safetensors")
// 2511 optional:
download_model(url="https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_2511_fp8_e4m3fn.safetensors", relative_path="models/diffusion_models", filename="qwen_image_edit_2511_fp8_e4m3fn.safetensors")
```

Do NOT download without confirmation. Document URLs, let user approve.

### Workflow

Templates: `image_qwen_image_edit_2509` (universal, multi-image + ControlNet) primary, `image_qwen_image_edit_2511` for material replace, or `image_qwen_image_edit` base. Via `search_templates(query="qwen edit")`. Verified on this host: `image_qwen_image_edit_2509` subgraph `eba40a3a` inputs `image, image2, image3 (optional), prompt, lora_name, negative_prompt, seed` (+ `qwen_2.5_vl_7b_fp8_scaled` + `qwen_image_vae`).

```
1. server_info() -> running true (5090 32GB)
2. upload_file(paths=["/absolute/input.jpg"]) -> ComfyUI input/
3. fetch_template(name="image_qwen_image_edit_2509", out_path="/tmp/qwen_edit.json") // universal; use 2511 only for material
4. list_workflow_slots(workflow_path="/tmp/qwen_edit.json") -> slots: e.g. `image`, `prompt`, `lora_name`, `seed` (subgraph  eba40a3a  - address like `433/xxx.prompt`)
5. set_workflow_slot(workflow_path="/tmp/qwen_edit.json", overrides=[{address:"<image slot>", value:"input.jpg"}, {address:"<prompt slot>", value:"replace the jacket with leather"}, {address:"<lora_name>", value:"Qwen-Image-Edit-2509-Lightning-4steps-V1.0-bf16.safetensors"}])
   // /tmp only, never repo. Lightning expects steps 4 cfg 1.
6. validate_workflow(workflow_path="/tmp/qwen_edit.json") -> local_check runnable true (needs diffusion fp8 + lora + vl 7b + vae present)
7. run_workflow(workflow_path="/tmp/qwen_edit.json", wait=False) -> prompt_id
8. job(action="wait", prompt_id, timeout_seconds=120)
9. fetch_outputs(prompt_id, out_dir="/tmp") -> then move to ~/content_library/image/ or requested path (/tmp only, clean after)
```

Slots: prompt = instruction (e.g. "change background to beach, keep subject"), image = uploaded filename, optional: steps=4 (with lightning) or 20-50 without, cfg 1-4.

Always `/tmp/qwen_edit.json` for workflow, `/tmp` for outputs. Never pollute repo. `fetch_outputs` out_dir must be `/tmp` or `~/content_library/image` absolute.

### Tips

- Lightning lora: steps 4, cfg 1. Without: steps 20-30, cfg 2-4.
- Upload first, then reference by filename in workflow slot.
- Validate before run. Check local_check runnable.
- Use wait=False + job wait for long runs.

## When to use which (examples)

- "resize to 1024px" -> magick
- "convert png to webp" -> magick
- "crop to square" -> magick
- "make jacket leather" -> Qwen
- "change background to forest" -> Qwen
- "restyle as oil painting" -> Qwen
- "remove person from background" -> Qwen

## Rules

- /tmp only for downloads/workflows/temp outputs. Never repo.
- Ask before large model downloads.
- magick preferred when it suffices (faster, no VRAM).
