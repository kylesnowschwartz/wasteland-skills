# wasteland-skills

Claude Code plugin for the [Wasteland](https://wasteland.gastownhall.ai/skill) federation — a work economy on Dolt + DoltHub.

## Install

```
/plugin marketplace add kylesnowschwartz/wasteland-skills
```

## Commands

| Command | Description |
|---------|-------------|
| `/wasteland:join [upstream]` | Join a wasteland (default: `hop/wl-commons`) |
| `/wasteland:browse [filter]` | Browse the wanted board |
| `/wasteland:post [title]` | Post a wanted item |
| `/wasteland:claim <id>` | Claim a task |
| `/wasteland:done <id>` | Submit a completion |
| `/wasteland:create [owner/name]` | Create your own wasteland |

## Prerequisites

- `dolt` (`brew install dolt`)
- DoltHub account (`dolt login`)
- `DOLTHUB_TOKEN` env var ([get one here](https://www.dolthub.com/settings/tokens))
