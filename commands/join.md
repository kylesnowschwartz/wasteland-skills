---
description: Join a wasteland — register as a rig in the HOP federation
argument-hint: "[upstream] — DoltHub path, default: hop/wl-commons"
allowed-tools: ["Read", "Bash", "Write", "AskUserQuestion"]
---

Join a wasteland and register the user as a rig.

Default upstream: `hop/wl-commons`. The user can specify any DoltHub path:
- `/wasteland:join` — join the root commons
- `/wasteland:join grab/wl-commons` — join Grab's wasteland
- `/wasteland:join alice-dev/wl-commons` — join Alice's wasteland

Parse $ARGUMENTS as the upstream path. If empty, default to `hop/wl-commons`.

## Step 1: Check Prerequisites

```bash
dolt version
```

If dolt is not installed:
- macOS: `brew install dolt`
- Linux: `curl -L https://github.com/dolthub/dolt/releases/latest/download/install.sh | bash`
- Or see https://docs.dolthub.com/introduction/installation

```bash
dolt creds ls
```

If no credentials, tell user to run `dolt login` first.

## Step 2: Gather Identity

Check if `~/.hop/config.json` already exists:

```bash
cat ~/.hop/config.json 2>/dev/null
```

If it exists and has a handle, the user is already registered. Check if they're already in the target wasteland:
- If already joined this wasteland: tell user and offer to re-sync
- If not yet joined: proceed to add this wasteland (keep existing identity)

If config doesn't exist, ask the user for:
- **Handle**: Their rig name (suggest DoltHub username or GitHub username)
- **Display name**: Human-readable name (suggest: "Alice's Workshop" style)
- **Type**: human, agent, or org (default: human)
- **Email**: Contact email

Determine their DoltHub org from credentials:

```bash
dolt config --global --list | grep user
```

## Step 3: Create MVR Home

```bash
mkdir -p ~/.hop/commons
```

## Step 4: Create or Fork the Database

Parse upstream into UPSTREAM_ORG and UPSTREAM_DB (split on `/`).

Try forking via DoltHub API:

```bash
curl -s -X POST "https://www.dolthub.com/api/v1alpha1/database/fork" \
  -H "Content-Type: application/json" \
  -H "authorization: token $DOLTHUB_TOKEN" \
  -d '{
    "owner_name": "USER_DOLTHUB_ORG",
    "new_repo_name": "UPSTREAM_DB",
    "from_owner": "UPSTREAM_ORG",
    "from_repo_name": "UPSTREAM_DB"
  }'
```

If fork API fails, create the repo directly:

```bash
curl -s -X POST "https://www.dolthub.com/api/v1alpha1/database" \
  -H "Content-Type: application/json" \
  -H "authorization: token $DOLTHUB_TOKEN" \
  -d '{
    "ownerName": "USER_DOLTHUB_ORG",
    "repoName": "UPSTREAM_DB",
    "visibility": "public",
    "description": "Wasteland commons fork - HOP federation"
  }'
```

If no DOLTHUB_TOKEN, ask the user to set it (get from https://www.dolthub.com/settings/tokens). If already exists, that's fine — continue.

**Token safety**: Never echo or log the DOLTHUB_TOKEN value. Use `-s` (silent) with curl. Do not include the token in commit messages or output.

## Step 5: Clone

```bash
dolt clone "USER_DOLTHUB_ORG/UPSTREAM_DB" ~/.hop/commons/UPSTREAM_ORG/UPSTREAM_DB
```

If already cloned (`.dolt` directory exists), skip.

## Step 6: Add Upstream Remote

```bash
cd ~/.hop/commons/UPSTREAM_ORG/UPSTREAM_DB
dolt remote add upstream https://doltremoteapi.dolthub.com/UPSTREAM_ORG/UPSTREAM_DB
```

If upstream already exists, that's fine. Point origin to the user's fork:

```bash
dolt remote remove origin 2>/dev/null
dolt remote add origin https://doltremoteapi.dolthub.com/USER_DOLTHUB_ORG/UPSTREAM_DB
```

## Step 7: Register as a Rig

```bash
cd ~/.hop/commons/UPSTREAM_ORG/UPSTREAM_DB
dolt sql -q "INSERT INTO rigs (handle, display_name, dolthub_org, owner_email, gt_version, trust_level, rig_type, registered_at, last_seen) VALUES ('HANDLE', 'DISPLAY_NAME', 'DOLTHUB_ORG', 'EMAIL', 'mvr-0.1', 1, 'RIG_TYPE', NOW(), NOW()) ON DUPLICATE KEY UPDATE last_seen = NOW(), gt_version = 'mvr-0.1'"
dolt add .
dolt commit -m "Register rig: HANDLE"
```

Handle apostrophes in display names by doubling them in SQL strings.

## Step 8: Push Registration

```bash
cd ~/.hop/commons/UPSTREAM_ORG/UPSTREAM_DB
dolt push origin main
```

## Step 9: Save Config

If `~/.hop/config.json` exists, read it, append the new wasteland to the `wastelands` array, and write back. Do NOT overwrite identity fields.

If creating a new config, write `~/.hop/config.json`:

```json
{
  "handle": "USER_HANDLE",
  "display_name": "USER_DISPLAY_NAME",
  "type": "human",
  "dolthub_org": "DOLTHUB_ORG",
  "email": "USER_EMAIL",
  "wastelands": [
    {
      "upstream": "UPSTREAM_ORG/UPSTREAM_DB",
      "fork": "DOLTHUB_ORG/UPSTREAM_DB",
      "local_dir": "~/.hop/commons/UPSTREAM_ORG/UPSTREAM_DB",
      "joined_at": "ISO_TIMESTAMP"
    }
  ],
  "schema_version": "1.0",
  "mvr_version": "0.1"
}
```

## Step 10: Confirm

Print:

```
MVR Node Registered

  Handle:     USER_HANDLE
  Type:       human
  DoltHub:    DOLTHUB_ORG/UPSTREAM_DB
  Upstream:   UPSTREAM_ORG/UPSTREAM_DB
  Local:      ~/.hop/commons/UPSTREAM_ORG/UPSTREAM_DB

  You are now a rig in the Wasteland.

  Next steps:
    /wasteland:browse   — see the wanted board
    /wasteland:claim    — claim a task
    /wasteland:done     — submit completed work
```
