# daedalOS desktop embed

The Hermes Desktop fork ([`koraussie7/hermes-desktop`](https://github.com/koraussie7/hermes-desktop)) adds a top-sidebar **Desktop** tab that embeds [daedalOS](https://github.com/DustinBrett/daedalOS) — a self-hosted, browser-side desktop similar to https://dustinbrett.com — in a sandboxed `iframe` pointing at `http://localhost:3030`.

This directory holds the MacBook-side runbook + launcher for the container.

## What runs where

| Layer | Where | Why |
|---|---|---|
| daedalOS container | **MacBook only** (`localhost:3030`) | Pure browser-side state (BrowserFS + IndexedDB); no volume needed. Image is ~2-3 GB (Playwright + Chromium). Putting it on the 3 backends for one client is wasteful. |
| Hermes Desktop `.app` | MacBook only | Tab is hardcoded to `http://localhost:3030`; iframe sandbox excludes `allow-top-navigation`. |
| Backend nodes | **untouched** | The `/llm` route from smart-router reaches the iframe-equivalent; no daedalOS traffic crosses the mesh. |

## Pull + start

```bash
bash daedal/launch-daedal.sh
#  - docker pull --platform linux/amd64 dustinbrett/daedalos:latest
#  - docker run -d --name daedalos --restart unless-stopped -p 3030:3000 dustinbrett/daedalos:latest
#  - polls http://127.0.0.1:3030/ until 200 (max 30s)
```

This is idempotent. Existing container → `docker start`. `--force` removes + recreates. `--no-pull` skips the pull (use when offline).

`install-macos.sh` calls this automatically in **section 3.5** on every install.

## Verify

```bash
curl -sI http://localhost:3030/ | head -5
# expect: HTTP/1.1 200
#         Cross-Origin-Opener-Policy: same-origin
#         Cross-Origin-Embedder-Policy: require-corp
#         (daedalOS requires COOP/COEP for SharedArrayBuffer)

curl -s http://localhost:3030/ | head -c 200
# expect: <!DOCTYPE html>...<title>daedalOS</title>...
```

## Logs / stop / restart

```bash
docker logs -f daedalos              # tail logs
docker restart daedalos              # bounce (state survives — BrowserFS lives in container FS)
docker stop daedalos                 # stop; data is preserved (volume-less, BrowserFS writes back on shutdown)
bash daedal/launch-daedal.sh --force # nuke + recreate
```

## When the Desktop tab is empty

1. `docker ps -a | grep daedalos` — is the container running?
2. `curl -sf http://localhost:3030/ -o /dev/null -w "%{http_code}\n"` — 200?
3. `docker logs --tail 50 daedalos` — any error?
4. macOS firewall prompt may have blocked `node` from opening `:3030` — System Settings → Network → Firewall → allow.

## Fork PR

The iframe sandbox is `allow-scripts allow-same-origin allow-forms allow-popups allow-modals` — no `allow-top-navigation`. Inside daedalOS's in-iframe Browser, `window.top.location = "..."` will throw `SecurityError` instead of hijacking the Electron window. Open the in-iframe URL in a real tab via the **Open in browser** button if a feature requires top-frame privileges.