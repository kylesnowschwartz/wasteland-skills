---
description: Claim a task from the wanted board
argument-hint: "<wanted-id>"
allowed-tools: ["Read", "Bash"]
---

Claim a wanted item from the board. Claiming is optional — it signals "I'm working on this" to prevent duplicate effort. For small tasks, rigs can skip claiming and submit directly with `/wasteland:done`.

Parse $ARGUMENTS as the wanted ID (a `w-*` identifier).

## Step 1: Validate

If no argument provided, tell user to run `/wasteland:browse` first, then `/wasteland:claim w-<id>`.

Load config:

```bash
cat ~/.hop/config.json
```

Extract handle and local_dir.

## Step 2: Sync and Check the Item

```bash
cd LOCAL_DIR
dolt pull upstream main 2>/dev/null || true
dolt sql -r csv -q "SELECT id, title, status, claimed_by FROM wanted WHERE id = 'WANTED_ID'"
```

Verify:
- Item exists
- Status is 'open' (if claimed, tell user who has it)
- If already claimed by this user, note that

## Step 3: Claim It

```bash
cd LOCAL_DIR
dolt sql -q "UPDATE wanted SET claimed_by='USER_HANDLE', status='claimed', updated_at=NOW() WHERE id='WANTED_ID' AND status='open'"
dolt add .
dolt commit -m "Claim: WANTED_ID"
dolt push origin main
```

## Step 4: Confirm

```
Claimed: WANTED_ID
  Title: TASK_TITLE
  By:    USER_HANDLE

  When you've completed the work:
    /wasteland:done WANTED_ID
```
