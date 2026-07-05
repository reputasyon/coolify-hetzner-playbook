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

4. **Use the deploy step** (full workflow: [`deploy.yml`](../.github/workflows/deploy.yml)):

   ```yaml
   - name: Deploy
     env:
       COOLIFY_TOKEN: ${{ secrets.COOLIFY_TOKEN }}
       COOLIFY_UUID: ${{ secrets.COOLIFY_APP_UUID }}
     run: |
       ssh -i ~/.ssh/deploy_key root@${{ secrets.SSH_HOST }} \
         "curl -sf 'http://localhost:8000/api/v1/deploy?uuid=${COOLIFY_UUID}&force=true' -H 'Authorization: Bearer ${COOLIFY_TOKEN}'"
   ```

## Verify

Push a commit to `main` (or run the workflow manually) and watch:

1. The Actions job's Deploy step exits 0 and prints Coolify's JSON response (contains `deployment_uuid`).
2. Coolify dashboard → the app → **Deployments** shows a new running deployment triggered at that moment.

## Notes

- `force=true` skips Coolify's "did the commit change?" check — you already gated the deploy in CI.
- Keep the SSH key **deploy-only**: if you want to harden further, restrict it in `authorized_keys` with `command="..."` to only allow the curl.
- This pattern also survives Cloudflare "Under Attack" mode, WAF rules, and any future edge blocking — CI traffic never touches the edge.
