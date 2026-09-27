---
name: cloudflare-tunnel
description: Use when user mentions cloudflare tunnel, cloudflared, telenedil tunnel, exposing localhost, ssh.telendil.com or telos.telendil.com access, or tunnel start/stop/status.
---

# Cloudflare Tunnel

Manage `telenedil` tunnel (`6ea31273-c860-49ad-bbf6-ec2793766e8c`).

## Tunneled Apps

| Public hostname | Local target | What |
|-----------------|--------------|------|
| `ssh.telendil.com` | `tcp://localhost:22` | SSH to this machine (needs WARP / cloudflared access client, not plain browser) |
| `telos.telendil.com` | `http://localhost:3002` | Telos app (`~/work/telos/app`, `bun --watch src/server/index.ts`) |

Fallback rule `http_status:404` = unknown hostname returns 404.

## Quick Reference

| Action | Command |
|--------|---------|
| Start (foreground) | `cloudflared tunnel run telenedil` |
| Start (background) | `nohup cloudflared tunnel run telenedil > /tmp/cloudflared-telenedil.log 2>&1 &` |
| Status | `cloudflared tunnel info telenedil` |
| List | `cloudflared tunnel list` |
| Check process | `pgrep -af "cloudflared tunnel run"` |
| Logs (background) | `tail -f /tmp/cloudflared-telenedil.log` |
| Stop (background) | `pkill -f "cloudflared tunnel run telenedil"` |

## Expose More Apps

1. App must listen locally first. Verify: `ss -tlnp | grep <port>`.
2. Add DNS route (creates CNAME `<host>` -> tunnel):
```bash
cloudflared tunnel route dns telenedil <newhost>.telendil.com
```
3. Edit `~/.cloudflared/config.yml`, insert rule ABOVE fallback:
```yaml
ingress:
  - hostname: <newhost>.telendil.com
    service: http://localhost:<port>
  - service: http_status:404
```
Service types: `http://localhost:PORT` (web), `tcp://localhost:PORT` (ssh/db, needs WARP client), `udp://`.
4. Validate + restart:
```bash
cloudflared tunnel ingress validate
pkill -f "cloudflared tunnel run telenedil"
nohup cloudflared tunnel run telenedil > /tmp/cloudflared-telenedil.log 2>&1 &
cloudflared tunnel info telenedil
```

Example: expose local dev on 5173 as `dev.telendil.com`:
```bash
cloudflared tunnel route dns telenedil dev.telendil.com
```
```yaml
  - hostname: dev.telendil.com
    service: http://localhost:5173
```

## Implementation

Start tunnel when user asks to activate/expose services:
```bash
nohup cloudflared tunnel run telenedil > /tmp/cloudflared-telenedil.log 2>&1 &
cloudflared tunnel info telenedil
```

Active = `info` shows `CONNECTIONS` with 4 edge addresses. Inactive = "does not have any active connection".

Stop only on explicit request. Kill by exact pattern, never broad `pkill cloudflared`.

## Common Mistakes

- Foreground `run` blocks shell. Use `nohup ... &` for background.
- Stale log misleads. Check `tunnel info`, not just log file.
- `cert.pem` / `*.json` in `~/.cloudflared/` are credentials. Never print, edit, commit.
- Ingress change needs config edit + restart tunnel.
