-- MVR Commons Schema v1.1
-- Minimum Viable Rig — the federation protocol as SQL
--
-- If your database has these tables, you're a protocol participant.
-- This is the shared contract between all rigs in a Wasteland.

-- Metadata and versioning
CREATE TABLE IF NOT EXISTS _meta (
    `key` VARCHAR(64) PRIMARY KEY,
    value TEXT
);

INSERT IGNORE INTO _meta (`key`, value) VALUES ('schema_version', '1.1');
INSERT IGNORE INTO _meta (`key`, value) VALUES ('wasteland_name', 'HOP Wasteland');
INSERT IGNORE INTO _meta (`key`, value) VALUES ('created_at', NOW());

-- Rig registry — the phone book
-- Each row is a protocol participant (human, agent, or org)
CREATE TABLE IF NOT EXISTS rigs (
    handle VARCHAR(255) PRIMARY KEY,      -- Unique rig identifier (DoltHub org name)
    display_name VARCHAR(255),            -- Human-readable name
    dolthub_org VARCHAR(255),             -- DoltHub organization
    hop_uri VARCHAR(512),                 -- hop://handle@host/chain (future)
    owner_email VARCHAR(255),             -- Contact email
    gt_version VARCHAR(32),               -- Software version (gt or mvr)
    trust_level INT DEFAULT 0,            -- 0=outsider, 1=registered, 2=contributor, 3=maintainer
    rig_type VARCHAR(16) DEFAULT 'human', -- human, agent, team, org
    parent_rig VARCHAR(255),             -- For agent/team rigs: the responsible human rig
    registered_at TIMESTAMP,
    last_seen TIMESTAMP
);

-- The wanted board — open work
-- Anyone can post. Anyone can claim. Validators stamp completions.
CREATE TABLE IF NOT EXISTS wanted (
    id VARCHAR(64) PRIMARY KEY,           -- w-<hash>
    title TEXT NOT NULL,
    description TEXT,
    project VARCHAR(64),                  -- gas-city, gastown, beads, hop, community
    type VARCHAR(32),                     -- feature, bug, design, rfc, docs
    priority INT DEFAULT 2,               -- 0=critical, 2=medium, 4=backlog
    tags JSON,                            -- ["go", "federation", "ux"]
    posted_by VARCHAR(255),               -- Rig handle of poster
    claimed_by VARCHAR(255),              -- Rig handle of claimer (NULL if open)
    status VARCHAR(32) DEFAULT 'open',    -- open, claimed, in_review, completed, withdrawn
    effort_level VARCHAR(16) DEFAULT 'medium', -- trivial, small, medium, large, epic
    evidence_url TEXT,                    -- PR link, commit, etc. (filled on completion)
    sandbox_required BOOLEAN DEFAULT FALSE,
    sandbox_scope JSON,                   -- file mount/exclude spec (future)
    sandbox_min_tier VARCHAR(32),         -- minimum worker tier (future)
    metadata JSON,                        -- Extensibility
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Completions — evidence of work done
-- A completion is the EVIDENCE. The STAMP is the reputation signal.
CREATE TABLE IF NOT EXISTS completions (
    id VARCHAR(64) PRIMARY KEY,           -- c-<hash>
    wanted_id VARCHAR(64),                -- References wanted.id
    completed_by VARCHAR(255),            -- Rig handle
    evidence TEXT,                        -- PR URL, commit hash, description
    validated_by VARCHAR(255),            -- Validator rig handle (maintainer+)
    stamp_id VARCHAR(64),                 -- References stamps.id
    parent_completion_id VARCHAR(64),     -- Fractal decomposition: sub-task references parent
    block_hash VARCHAR(64),              -- Computed hash of this row's contents
    hop_uri VARCHAR(512),                -- Canonical HOP identifier
    metadata JSON,                        -- Extensibility
    completed_at TIMESTAMP,
    validated_at TIMESTAMP
);

-- Stamps — validated work (the reputation backbone)
-- A stamp is a multi-dimensional attestation from one rig about another,
-- anchored to evidence. You cannot write in your own yearbook.
CREATE TABLE IF NOT EXISTS stamps (
    id VARCHAR(64) PRIMARY KEY,           -- s-<hash>
    author VARCHAR(255) NOT NULL,         -- Rig that signs (validator)
    subject VARCHAR(255) NOT NULL,        -- Rig being stamped (worker)
    valence JSON NOT NULL,               -- {"quality": 4, "reliability": 5, "creativity": 3}
    confidence FLOAT DEFAULT 1.0,        -- 0.0-1.0
    severity VARCHAR(16) DEFAULT 'leaf', -- leaf, branch, root
    context_id VARCHAR(64),              -- wanted/completion ID (the evidence)
    context_type VARCHAR(32),            -- 'completion', 'endorsement', 'boot_block'
    skill_tags JSON,                     -- ["go", "federation"] from wanted item
    message TEXT,                        -- Optional: "Exceptional federation work"
    prev_stamp_hash VARCHAR(64),         -- Passbook chain
    block_hash VARCHAR(64),              -- Computed hash
    hop_uri VARCHAR(512),                -- Canonical HOP identifier
    metadata JSON,                       -- Extensibility
    created_at TIMESTAMP,
    CHECK (author != subject)            -- Yearbook rule: can't sign your own
);

-- Badges — computed achievements (the collection game)
CREATE TABLE IF NOT EXISTS badges (
    id VARCHAR(64) PRIMARY KEY,
    rig_handle VARCHAR(255),             -- Who earned it
    badge_type VARCHAR(64),               -- first_blood, polyglot, bridge_builder, etc.
    evidence TEXT,                        -- What triggered it
    metadata JSON,                       -- Extensibility
    awarded_at TIMESTAMP
);

-- Chain metadata — tracks the chain hierarchy
CREATE TABLE IF NOT EXISTS chain_meta (
    chain_id VARCHAR(64) PRIMARY KEY,
    chain_type VARCHAR(32),               -- entity, project, community, utility, currency
    parent_chain_id VARCHAR(64),
    hop_uri VARCHAR(512),
    dolt_database VARCHAR(255),           -- The Dolt database backing this chain
    metadata JSON,                       -- Extensibility
    created_at TIMESTAMP
);
