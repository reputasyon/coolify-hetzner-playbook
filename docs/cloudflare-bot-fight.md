# Cloudflare Bot Fight Mode silently blocks your deploys

**Symptom:** GitHub → Coolify deploy webhooks (or direct Coolify API calls from GitHub Actions) stop working, or never worked. No useful error — requests just fail or hang. Deploys work fine when you click the button in the Coolify dashboard.

**Cause:** Cloudflare's Bot Fight Mode (and Super Bot Fight Mode) classifies GitHub Actions runners' IPs as bots and blocks them **before** the request ever reaches your server. Since your Coolify domain is proxied through Cloudflare, every webhook and API call from CI dies at the edge.

**The wrong fixes:** turning off Bot Fight Mode (you want it — it blocks real scraper/bot traffic), or allowlisting GitHub's IP ranges (they're large, change over time, and Bot Fight Mode on the free plan ignores IP allow rules anyway).

**The right fix:** don't go through Cloudflare at all. SSH into the server from Actions and call Coolify's API on `localhost:8000` from the inside.

```
GitHub Actions ──ssh──▶ your server ──curl──▶ localhost:8000 (Coolify API)
                (Cloudflare never sees this)
```

## Prerequisites

- Coolify running on the server (API listens on `localhost:8000` by default)
- Ability to add an SSH public key to the server
- A Coolify API token: Coolify dashboard → **Keys & Tokens → API tokens → Create** (deploy permission is enough)

## Check

```bash
# On the server — confirm the Coolify API answers locally:
curl -sf http://localhost:8000/api/v1/version -H "Authorization: Bearer $COOLIFY_TOKEN"
# Expected: a version string. If connection refused, find the port: docker port coolify
```

## Apply

1. **Create a deploy-only SSH key** (on your machine, not the server):

   ```bash
   ssh-keygen -t ed25519 -f coolify_deploy -N "" -C "github-actions-deploy"
   cat coolify_deploy.pub >> ~/.ssh/authorized_keys   # run on the SERVER
   ```

2. **Find each app's UUID** — it's in the Coolify dashboard URL when the app is open: `/project/.../application/<THIS-IS-THE-UUID>`.

3. **Add GitHub secrets** (repo → Settings → Secrets → Actions): `SSH_HOST`, `SSH_PRIVATE_KEY` (contents of `coolify_deploy`), `COOLIFY_TOKEN`, `COOLIFY_APP_UUID`.

4. **Use the deploy step** (full workflow: [`deploy.yml`](../templates/deploy.yml)):

   ```yaml
   - name: Deploy
     env:
       COOLIFY_TOKEN: ${{ secrets.COOLIFY_TOKEN }}
       COOLIFY_UUID: ${{ secrets.COOLIFY_APP_UUID }}
     run: |
       ssh -i ~/.ssh/deploy_key root@${{ secrets.SSH_HOST }} \
         "curl -sf 'http://localhost:8000/api/v1/deploy?uuid=${COOLIFY_UUID}' -H 'Authorization: Bearer ${COOLIFY_TOKEN}'"
   ```

## Verify

Push a commit to `main` (or run the workflow manually) and watch:

1. The Actions job's Deploy step exits 0 and prints Coolify's JSON response (contains `deployment_uuid`).
2. Coolify dashboard → the app → **Deployments** shows a new running deployment triggered at that moment.

## Notes

- Appending `&force=true` forces a **no-cache rebuild**. Don't make it your default — it slows every deploy and throws away the build cache. Reserve it for when a stale cached layer is actively causing a bad build.
- This pattern also survives Cloudflare "Under Attack" mode, WAF rules, and any future edge blocking — CI traffic never touches the edge.

## Harden further (optional but cheap)

The basic setup gives CI a root SSH key that can run anything. Two upgrades close most of that exposure:

**1. Forced command** — pin the key to the deploy curl in `authorized_keys`, so even a leaked key can only trigger deploys:

```
command="curl -sf \"http://localhost:8000/api/v1/deploy?uuid=$SSH_ORIGINAL_COMMAND\" -H \"Authorization: Bearer YOUR_COOLIFY_TOKEN\"",no-port-forwarding,no-agent-forwarding,no-pty ssh-ed25519 AAAA... github-actions-deploy
```

The workflow then sends only the UUID: `ssh -i ~/.ssh/deploy_key root@$HOST "$COOLIFY_UUID"`. The token lives on the server, never in CI. (A dedicated non-root user works too, but with a forced command the account's privileges barely matter.)

**2. Pin the host key** — `ssh-keyscan` on every run is trust-on-first-use, every time; a MITM between GitHub and your server could intercept it. Instead, capture once and store as a secret:

```bash
ssh-keyscan -H YOUR_SERVER_IP        # run locally, put output in secret SSH_KNOWN_HOSTS
```

```yaml
- run: echo "${{ secrets.SSH_KNOWN_HOSTS }}" >> ~/.ssh/known_hosts   # instead of ssh-keyscan
```
