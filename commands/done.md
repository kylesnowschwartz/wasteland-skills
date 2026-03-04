---
description: Submit completion for a wanted item
argument-hint: "<wanted-id>"
allowed-tools: ["Read", "Bash", "AskUserQuestion"]
---

Submit completion for a wanted item. Works whether or not the item was claimed first — rigs can submit directly against open items (bounty style) or against items they previously claimed.

Parse $ARGUMENTS as the wanted ID (a `w-*` identifier).

## Step 1: Validate

If no argument provided, show the user's claimed items and open items:

```bash
cd LOCAL_DIR
dolt sql -r tabular -q "SELECT id, title, status FROM wanted WHERE (claimed_by = 'USER_HANDLE' AND status = 'claimed') OR status = 'open' ORDER BY status, priority ASC"
```

Load config:

```bash
cat ~/.hop/config.json
```

Extract handle and local_dir.

## Step 2: Check the Item

```bash
cd LOCAL_DIR
dolt sql -r csv -q "SELECT id, title, status, claimed_by FROM wanted WHERE id = 'WANTED_ID'"
```

Verify:
- Item exists
- Status is 'open', 'claimed', or 'in_review'
- If 'claimed' by someone else, warn but allow submission (competing completion)
- If 'completed', tell user it's already done
- If 'in_review', note there's already a pending submission but allow another

## Step 3: Gather Evidence

Ask the user for evidence of completion:
- A URL (PR, commit, deployed page, etc.)
- A description of what was done
- A file path to deliverables

The evidence goes into `completions.evidence` as text.

## Step 4: Generate Completion ID

```bash
echo "c-$(openssl rand -hex 5)"
```

## Step 5: Submit Completion

```bash
cd LOCAL_DIR
dolt sql -q "INSERT INTO completions (id, wanted_id, completed_by, evidence, completed_at) VALUES ('COMPLETION_ID', 'WANTED_ID', 'USER_HANDLE', 'EVIDENCE_TEXT', NOW())"
dolt sql -q "UPDATE wanted SET status='in_review', updated_at=NOW() WHERE id='WANTED_ID' AND status IN ('open', 'claimed')"
dolt add .
dolt commit -m "Complete: WANTED_ID"
dolt push origin main
```

The status update uses `IN ('open', 'claimed')` so it works for both claimed and unclaimed items, and is a no-op if already `in_review`.

## Step 6: Confirm

```
Completion Submitted: COMPLETION_ID
  Task:     WANTED_ID — TASK_TITLE
  By:       USER_HANDLE
  Evidence: EVIDENCE_TEXT
  Status:   in_review (awaiting validation)

  A validator will review and stamp your work.
  Your completion is visible in the commons.
```
