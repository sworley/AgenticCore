# Runbook: Rotate Git PAT

**Purpose:** Rotate a Git Personal Access Token (PAT) stored in the `pass` credential store.

**When to run:** Token expiration, security incident, or scheduled rotation
**Estimated time:** 5-10 minutes

---

## Prerequisites

- Access to Git UI at the target host
- `pass` store writable (`gpg-agent` unlocked)
- `direnv` active in the working directory

---

## Procedure

### Step 1 — Create the new token in Git

1. Log in to Git
2. Navigate to **User Settings → Access Tokens**
3. Click **Add new token**
4. Name: use a descriptive name with expiry date (e.g., `dev-user-api-2027-06-22`)
5. Scopes: `api` (minimum required)
6. Set expiration date
7. Click **Create personal access token**
8. **Copy the token value immediately** — it will not be shown again

### Step 2 — Update the pass store

```sh
pass edit git/<host>/pat
```

Replace the old token value with the new one. Save and close.

### Step 3 — Verify the new token

```sh
direnv reload   # re-inject updated credential
curl -s --header "PRIVATE-TOKEN: $(pass show git/<host>/pat)" \
  "https://<host>/api/v4/user" | jq '.username'
```

Expected: your Git username.

### Step 4 — Revoke the old token

In Git UI:
1. Navigate to **User Settings → Access Tokens**
2. Find the old token
3. Click **Revoke**

### Step 5 — Test all active benches

If multiple worktrees are active, reload direnv in each:
```sh
for bench in $(git worktree list --porcelain | grep "^worktree" | awk '{print $2}'); do
  echo "Reloading: $bench"
  (cd "$bench" && direnv reload 2>/dev/null || echo "  skipped (no .envrc)")
done
```

---

## Verification

- [ ] `pass show git/<host>/pat` returns the new token
- [ ] `curl` test returns your username
- [ ] Old token is revoked in Git UI
- [ ] All active benches are using the new token

---

## Rollback

If the new token was created but direnv has not been reloaded:
```sh
direnv reload
```

If the new token is invalid (wrong scopes, etc.), repeat Step 1 and create a replacement.
Do not revoke the old token until the new one is verified.
