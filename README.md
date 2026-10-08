# opencode-pstack

Use Cursor's [pstack](https://github.com/cursor/plugins/tree/main/pstack) skills and agents inside opencode, without manual copying.

pstack is officially a Cursor plugin, so opencode users had to `git pull` the plugins repo and hand-copy files into `~/.config/opencode/skills` and `~/.config/opencode/agents` on every update. This repo replaces that with one command, plus an opencode plugin that lets agents run it from inside a session.

## Contents

- `scripts/sync-pstack.sh` — the sync script. The single source of truth.
- `plugins/pstack-sync.ts` — thin opencode plugin exposing the script as the `pstack_sync` tool. No logic lives here.

## Requirements

- `git`, `rsync`, `perl` (preinstalled on macOS)
- opencode with `@opencode-ai/plugin` in `~/.config/opencode/package.json` (only needed for the `pstack_sync` tool)

## Install

1. Check out only `pstack` from the plugins repo (sparse, no need for the whole thing):

```bash
git clone --filter=blob:none --sparse https://github.com/cursor/plugins.git ~/.local/share/cursor-plugins
git -C ~/.local/share/cursor-plugins sparse-checkout set pstack
```

2. Copy the two files into your opencode config (paths mirror this repo):

```bash
cp plugins/pstack-sync.ts ~/.config/opencode/plugins/
cp scripts/sync-pstack.sh ~/.config/opencode/scripts/
chmod +x ~/.config/opencode/scripts/sync-pstack.sh
```

3. Edit the model mapping at the top of `sync-pstack.sh` to match models you actually have:

```bash
FROM_CODE="grok-4.7-xhigh-fast"; TO_CODE="grok-4.6-fast-xhigh"
FROM_JUDGE="claude-opus-5-5-xhigh"; TO_JUDGE="claude-fable-5-1-thinking-max"
```

4. Restart opencode (plugins load at startup).

## Usage

From inside opencode, just ask:

```
sync pstack
```

The agent calls the `pstack_sync` tool. It accepts `dry_run` (preview only) and `no_pull` (use the local checkout as-is).

From a terminal:

```bash
~/.config/opencode/scripts/sync-pstack.sh
~/.config/opencode/scripts/sync-pstack.sh --dry-run   # preview
~/.config/opencode/scripts/sync-pstack.sh --no-pull    # skip git pull
PSTACK_ROOT=/path/to/plugins sync-pstack.sh            # custom checkout location
SKIP_PULL=1 sync-pstack.sh                             # same as --no-pull
```

## What a sync does

1. `git pull --ff-only` the checkout (skipped with `--no-pull` / `SKIP_PULL=1`).
2. `rsync` `pstack/skills/` → `~/.config/opencode/skills/`, except `setup-pstack` (fully rewritten for opencode, never overwritten).
3. `rsync` `pstack/agents/` → `~/.config/opencode/agents/`, except `poteto-agent.md` (opencode-specific resume behavior, never overwritten).
4. Applies opencode transforms to synced files only: the model slug mapping plus `~/.cursor/` → `~/.opencode/`, and the stricter poteto-mode todolist first line.
5. Never deletes anything, so opencode-only skills (yours, twg, etc.) survive every sync.

The script is idempotent. Re-running converges to the same state.

After syncing, run `/setup-pstack` once so `~/.opencode/rules/pstack-models.mdc` picks up any new role defaults.

## License

MIT
