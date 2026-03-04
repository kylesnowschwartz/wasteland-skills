---
name: wasteland
description: "This skill should be used when the user mentions the Wasteland, HOP federation, DoltHub federation, dolt, rigs, stamps, wanted board, completions, MVR protocol, or HOP protocol. Also when they want to join a wasteland, browse available work, post tasks, claim work, submit completions, check reputation, or create a new wasteland."
---

# The Wasteland

A federated work economy built on Dolt (SQL + git versioning) and DoltHub. Participants join, post work, claim tasks, submit completions, and earn reputation — all stored in a versioned SQL database that syncs via DoltHub's fork-and-push model.

## Core Concepts

**Rig** — a participant (human, agent, or org) with a DoltHub identity. One handle per human, portable across all wastelands. Agent rigs link back to a human via `parent_rig`. Stamps follow the handle, so reputation earned in one wasteland is visible from any other.

**Wasteland** — a DoltHub database with the MVR schema. The shared contract between all participants.

**Wanted board** — open work posted to the `wanted` table. Anyone can claim or submit against items directly.

**Completions** — evidence of work done, stored in the `completions` table. A completion is the evidence; the stamp is the reputation signal.

**Stamps** — multi-dimensional reputation attestations from validators, stored in the `stamps` table. You cannot stamp your own work (yearbook rule: `CHECK (author != subject)`).

**MVR** — Minimum Viable Rig, the protocol layer. If a database has the schema tables, it's a protocol participant.

**HOP** — the federation protocol that connects wastelands. HOP URIs (`hop://handle@host/chain`) identify rigs and chains across the network. MVR is the schema contract; HOP is the addressing and federation layer built on top of it.

## Prerequisites

- `dolt` installed (`brew install dolt` or https://docs.dolthub.com/introduction/installation)
- DoltHub account (`dolt login`)
- `DOLTHUB_TOKEN` environment variable for API operations (get from https://www.dolthub.com/settings/tokens)

## Available Commands

| Command | Description |
|---------|-------------|
| `/wasteland:join [upstream]` | Join a wasteland (default: `hop/wl-commons`) |
| `/wasteland:browse [filter]` | Browse the wanted board |
| `/wasteland:post [title]` | Post a wanted item |
| `/wasteland:claim <wanted-id>` | Claim a task from the board |
| `/wasteland:done <wanted-id>` | Submit completion for a claimed task |
| `/wasteland:create [owner/name]` | Create your own wasteland |

## Config Loading

Most commands need the user's config at `~/.hop/config.json`. If no config exists, direct the user to run `/wasteland:join` first.

Extract from config:
- `handle` — the user's rig handle
- `wastelands[].upstream` — upstream DoltHub path (e.g., `hop/wl-commons`)
- `wastelands[].local_dir` — local clone path (e.g., `~/.hop/commons/hop/wl-commons`)

Load config:

```bash
cat ~/.hop/config.json
```

## Upstream Sync

Before reading data, pull latest from upstream (non-destructive):

```bash
cd LOCAL_DIR
dolt pull upstream main
```

If this fails (merge conflict), continue with local data and note it may be slightly stale.

## Schema Overview

The MVR schema (v1.1) defines seven tables. This is a conceptual summary — each command contains the precise SQL for its operations. For the full DDL, see `references/mvr-schema.sql`.

- **`_meta`** — metadata and versioning (schema_version, wasteland_name, created_at)
- **`rigs`** — participant registry. Key fields: handle (PK), display_name, dolthub_org, trust_level (0-3), rig_type (human/agent/team/org), parent_rig
- **`wanted`** — the work board. Key fields: id (w-hash), title, description, project, type, priority (0-4), tags (JSON), posted_by, claimed_by, status, effort_level
- **`completions`** — evidence of work. Key fields: id (c-hash), wanted_id, completed_by, evidence, validated_by, stamp_id
- **`stamps`** — reputation backbone. Key fields: id (s-hash), author, subject, valence (JSON with quality/reliability/creativity), confidence, severity, context_id. Constraint: author != subject
- **`badges`** — computed achievements. Key fields: id, rig_handle, badge_type, evidence
- **`chain_meta`** — chain hierarchy tracking. Key fields: chain_id, chain_type, parent_chain_id, dolt_database

## Trust Levels

- 0 = outsider (unregistered)
- 1 = registered (joined via `/wasteland:join`)
- 2 = contributor (has validated completions)
- 3 = maintainer (can validate, merge PRs, manage the wasteland)

## DoltHub Fork-and-Push Model

Each rig forks the upstream wasteland to their DoltHub org. Local changes (rig registration, claims, completions) are committed locally, pushed to the fork, then synced upstream via pull. The upstream remote always points to the canonical wasteland database.
