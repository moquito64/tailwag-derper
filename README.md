# tailwag-derper

Standalone DERP relay for tailwag's break-glass path. Deliberately outside
Camelot's management plane — no Komodo, no Semaphore, no NetBird dependency.
Provisioned by hand from Terraform run locally, updated via GitHub Actions,
not via anything self-hosted.

## Layout

- `terraform/` — GCP e2-micro VM (Always Free eligible), static external IP,
  firewall rules (80/tcp, 443/tcp, 3478/udp, 22/tcp restricted to your IP).
- `docker/` — the derper container build + its runtime compose file.
- `.github/workflows/` — builds and publishes the image to GHCR on push.

## One-time setup, in order

1. **New GCP project.** Don't reuse an existing one — keep this fully
   separate from anything else you run.
2. **Push this repo to GitHub** (e.g. `moquito64/tailwag-derper`), let the
   Actions workflow run once, then mark the resulting package **public**
   in the repo's Package settings (Settings → Packages → tailwag-derper →
   Change visibility). The VM's anonymous `docker pull` needs this.
3. **DNS.** After `terraform apply` prints `derper_ip`, point
   `wag.wolfandcrow.tech` (or whatever hostname you want) at it — A record,
   and AAAA too if the VM ever gets a v6 address. Update `--hostname` in
   `docker/docker-compose.yml` to match before the container starts, since
   that's what LetsEncrypt validates against.
4. `cd terraform && terraform init && terraform apply` — you'll be prompted
   for `project_id`, `ssh_source_ranges`, and `repo_url`.
5. Confirm: `curl -v https://wag.wolfandcrow.tech/derp/probe` should return
   200 once the cert issues (can take a minute or two on first boot).

## Baking this into a tailwag token

Once it's up, pin it into a saved key so the token is self-contained (no
DERP map fetch at connect time):

```
tailwag genkey --region=wag.wolfandcrow.tech
```
The hostname form of `--region` already fully embeds this relay's node
info in the token. Don't combine it with `--embed-derp-map` — that flag
assumes a numeric DERP-map region ID and panics on a hostname region.

That gives you a `tc...` token embedding this relay's DERP node info
directly — the thing to hand to tailwag clients on kyner/hector/merlin/wart.

## Not done yet

- `--verify-clients=false` is deliberate for now (no local tailscaled to
  check against) — token possession via `--allow=nodekey:...` on each
  tailwag server is the actual gate, not this relay.
- No mesh key / `mesh.go` config — single node, nothing to mesh with yet.
- No monitoring wired in (no Beszel agent here on purpose — see the
  Camelot-independence note above). A simple external uptime check
  (something that isn't Uptime Kuma on your own fleet) is worth adding.
