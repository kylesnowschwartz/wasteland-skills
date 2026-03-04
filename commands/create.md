---
description: Create your own wasteland — a new DoltHub database from the MVR schema
argument-hint: "[owner/name]"
allowed-tools: ["Read", "Bash", "Write", "AskUserQuestion"]
---

Create a new wasteland — a DoltHub database initialized with the MVR schema. The creator becomes the first rig and maintainer (trust_level=3). The wasteland is registered in the root commons (`hop/wl-commons`) via PR, making it discoverable by the federation.

Parse $ARGUMENTS as `owner/name`. If empty, ask the user.

## Step 1: Check Prerequisites

```bash
dolt version
```

If dolt is not installed:
- macOS: `brew install dolt`
- Linux: `curl -L https://github.com/dolthub/dolt/releases/latest/download/install.sh | bash`

```bash
dolt creds ls
```

If no credentials, tell user to run `dolt login` first.

## Step 2: Gather Details

If database path not provided, ask for:
- **Owner**: DoltHub org name (suggest DoltHub username)
- **Database name**: Usually `wl-commons` (conventional name)

Then ask for:
- **Wasteland name**: Human-readable name (e.g., "Acme Engineering", "Indie Builders")
- **Description**: Optional description for DoltHub
- **Display name**: User's display name for the rigs table
- **Email**: Contact email

Determine DoltHub org:

```bash
dolt config --global --list | grep user
```

## Step 3: Verify Database Doesn't Exist

```bash
curl -s "https://www.dolthub.com/api/v1alpha1/OWNER/DB_NAME" \
  -H "authorization: token $DOLTHUB_TOKEN" | head -5
```

If it exists, suggest `/wasteland:join OWNER/DB_NAME` instead.

**Token safety**: Never echo or log the DOLTHUB_TOKEN value. Use `-s` (silent) with curl. Do not include the token in commit messages or output.

## Step 4: Create Database on DoltHub

```bash
curl -s -X POST "https://www.dolthub.com/api/v1alpha1/database" \
  -H "Content-Type: application/json" \
  -H "authorization: token $DOLTHUB_TOKEN" \
  -d '{
    "ownerName": "OWNER",
    "repoName": "DB_NAME",
    "visibility": "public",
    "description": "Wasteland: WASTELAND_NAME — a HOP federation commons"
  }'
```

## Step 5: Initialize Schema

Create a temp dolt database and apply the MVR schema:

```bash
TMPDIR=$(mktemp -d)
cd $TMPDIR
dolt init --name OWNER --email EMAIL
```

Apply the full schema via heredoc:

```bash
dolt sql <<'SCHEMA'
CREATE TABLE IF NOT EXISTS _meta (
    `key` VARCHAR(64) PRIMARY KEY,
    value TEXT
);

INSERT IGNORE INTO _meta (`key`, value) VALUES ('schema_version', '1.1');
INSERT IGNORE INTO _meta (`key`, value) VALUES ('wasteland_name', 'HOP Wasteland');
INSERT IGNORE INTO _meta (`key`, value) VALUES ('created_at', NOW());

CREATE TABLE IF NOT EXISTS rigs (
    handle VARCHAR(255) PRIMARY KEY,
    display_name VARCHAR(255),
    dolthub_org VARCHAR(255),
    hop_uri VARCHAR(512),
    owner_email VARCHAR(255),
    gt_version VARCHAR(32),
    trust_level INT DEFAULT 0,
    rig_type VARCHAR(16) DEFAULT 'human',
    parent_rig VARCHAR(255),
    registered_at TIMESTAMP,
    last_seen TIMESTAMP
);

CREATE TABLE IF NOT EXISTS wanted (
    id VARCHAR(64) PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    project VARCHAR(64),
    type VARCHAR(32),
    priority INT DEFAULT 2,
    tags JSON,
    posted_by VARCHAR(255),
    claimed_by VARCHAR(255),
    status VARCHAR(32) DEFAULT 'open',
    effort_level VARCHAR(16) DEFAULT 'medium',
    evidence_url TEXT,
    sandbox_required BOOLEAN DEFAULT FALSE,
    sandbox_scope JSON,
    sandbox_min_tier VARCHAR(32),
    metadata JSON,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS completions (
    id VARCHAR(64) PRIMARY KEY,
    wanted_id VARCHAR(64),
    completed_by VARCHAR(255),
    evidence TEXT,
    validated_by VARCHAR(255),
    stamp_id VARCHAR(64),
    parent_completion_id VARCHAR(64),
    block_hash VARCHAR(64),
    hop_uri VARCHAR(512),
    metadata JSON,
    completed_at TIMESTAMP,
    validated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS stamps (
    id VARCHAR(64) PRIMARY KEY,
    author VARCHAR(255) NOT NULL,
    subject VARCHAR(255) NOT NULL,
    valence JSON NOT NULL,
    confidence FLOAT DEFAULT 1.0,
    severity VARCHAR(16) DEFAULT 'leaf',
    context_id VARCHAR(64),
    context_type VARCHAR(32),
    skill_tags JSON,
    message TEXT,
    prev_stamp_hash VARCHAR(64),
    block_hash VARCHAR(64),
    hop_uri VARCHAR(512),
    metadata JSON,
    created_at TIMESTAMP,
    CHECK (author != subject)
);

CREATE TABLE IF NOT EXISTS badges (
    id VARCHAR(64) PRIMARY KEY,
    rig_handle VARCHAR(255),
    badge_type VARCHAR(64),
    evidence TEXT,
    metadata JSON,
    awarded_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS chain_meta (
    chain_id VARCHAR(64) PRIMARY KEY,
    chain_type VARCHAR(32),
    parent_chain_id VARCHAR(64),
    hop_uri VARCHAR(512),
    dolt_database VARCHAR(255),
    metadata JSON,
    created_at TIMESTAMP
);
SCHEMA
```

## Step 6: Configure Wasteland Metadata

```bash
cd $TMPDIR
dolt sql -q "REPLACE INTO _meta (\`key\`, value) VALUES ('wasteland_name', 'WASTELAND_NAME')"
dolt sql -q "REPLACE INTO _meta (\`key\`, value) VALUES ('created_by', 'HANDLE')"
dolt sql -q "REPLACE INTO _meta (\`key\`, value) VALUES ('upstream', 'hop/wl-commons')"
dolt sql -q "REPLACE INTO _meta (\`key\`, value) VALUES ('phase1_mode', 'wild_west')"
dolt sql -q "REPLACE INTO _meta (\`key\`, value) VALUES ('genesis_validators', '[\"HANDLE\"]')"
dolt add .
dolt commit -m "Initialize WASTELAND_NAME wasteland from MVR schema v1.1"
```

## Step 7: Register Creator as First Rig

```bash
cd $TMPDIR
dolt sql -q "INSERT INTO rigs (handle, display_name, dolthub_org, owner_email, gt_version, rig_type, trust_level, registered_at, last_seen) VALUES ('HANDLE', 'DISPLAY_NAME', 'OWNER', 'EMAIL', 'mvr-0.1', 'human', 3, NOW(), NOW())"
dolt add rigs
dolt commit -m "Register creator: HANDLE (maintainer)"
```

The creator gets trust_level=3 (maintainer).

## Step 8: Push to DoltHub

```bash
cd $TMPDIR
dolt remote add origin https://doltremoteapi.dolthub.com/OWNER/DB_NAME
dolt push origin main
```

## Step 9: Register in Root Commons

Register the new wasteland in the root commons via `chain_meta`:

```bash
CHAIN_ID="wl-$(openssl rand -hex 8)"

ROOT_TMP=$(mktemp -d)
dolt clone hop/wl-commons $ROOT_TMP
cd $ROOT_TMP

dolt checkout -b "register-wasteland/OWNER/DB_NAME"

dolt sql -q "INSERT INTO chain_meta (chain_id, chain_type, parent_chain_id, hop_uri, dolt_database, created_at) VALUES ('$CHAIN_ID', 'community', NULL, 'hop://OWNER/DB_NAME', 'OWNER/DB_NAME', NOW())"
dolt add chain_meta
dolt commit -m "Register wasteland: WASTELAND_NAME (OWNER/DB_NAME)"

dolt push origin "register-wasteland/OWNER/DB_NAME"
```

Then open a DoltHub PR from the registration branch to main on `hop/wl-commons`. If the user has a fork, push the branch there and open the PR from the fork.

If root registration fails, it's non-fatal. The wasteland works without it — it just won't be discoverable yet.

## Step 10: Save Config

Update `~/.hop/config.json` to track the new wasteland. If config exists, append to the `wastelands` array. If not, create a new config:

```json
{
  "handle": "HANDLE",
  "display_name": "DISPLAY_NAME",
  "type": "human",
  "dolthub_org": "OWNER",
  "email": "EMAIL",
  "wastelands": [
    {
      "upstream": "OWNER/DB_NAME",
      "fork": "OWNER/DB_NAME",
      "local_dir": "~/.hop/commons/OWNER/DB_NAME",
      "joined_at": "ISO_TIMESTAMP",
      "is_owner": true
    }
  ],
  "schema_version": "1.0",
  "mvr_version": "0.1"
}
```

Clean up temp directories.

## Step 11: Confirm

```
Wasteland Created: WASTELAND_NAME

  Database:     OWNER/DB_NAME (DoltHub)
  Chain ID:     CHAIN_ID
  Creator:      HANDLE (maintainer, trust_level=3)
  Root:         registered (PR: URL) | not registered (standalone)

  Others can join with:
    /wasteland:join OWNER/DB_NAME

  Your wasteland commands:
    /wasteland:browse          — see the wanted board
    /wasteland:post            — post work to your board
    /wasteland:claim <id>      — claim a wanted item
    /wasteland:done <id>       — submit completed work
```
