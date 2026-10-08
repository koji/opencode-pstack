#!/usr/bin/env bash
# Sync pstack (cursor/plugins repo) -> opencode skills/agents.
# Idempotent: safe to re-run. Never deletes opencode-only skills (no --delete).
# Protected (opencode custom, never overwritten): skills/setup-pstack, agents/poteto-agent.md
# Transforms applied after copy: model slugs + ~/.cursor/ paths -> opencode values,
# plus the poteto-mode todolist patch.
set -euo pipefail

ROOT="${PSTACK_ROOT:-$HOME/.local/share/cursor-plugins}"
SRC="$ROOT/pstack"
DST_SKILLS="$HOME/.config/opencode/skills"
DST_AGENTS="$HOME/.config/opencode/agents"
# Model slug mapping: upstream (Cursor) -> your opencode models.
# Edit these two lines to match the models you actually have.
FROM_CODE="grok-4.7-xhigh-fast"; TO_CODE="grok-4.6-fast-xhigh"
FROM_JUDGE="claude-opus-5-5-xhigh"; TO_JUDGE="claude-fable-5-1-thinking-max"
DRY_RUN=""
DO_PULL="1"
for a in "$@"; do
  case "$a" in
    --dry-run) DRY_RUN="--dry-run" ;;
    --no-pull) DO_PULL="0" ;;
  esac
done

if [ ! -d "$SRC/skills" ]; then
  echo "error: pstack not found at $SRC (set PSTACK_ROOT)" >&2
  exit 1
fi

if [ "$DRY_RUN" = "--dry-run" ]; then
  RSYNC_ARGS="-an"
  echo "dry-run: no changes will be written"
else
  RSYNC_ARGS="-a"
  if [ "$DO_PULL" = "1" ] && [ -z "${SKIP_PULL:-}" ]; then
    git -C "$ROOT" pull --ff-only
  else
    echo "skipping git pull"
  fi
fi

# shellcheck disable=SC2086
command rsync $RSYNC_ARGS --exclude 'setup-pstack' "$SRC/skills/" "$DST_SKILLS/"
# shellcheck disable=SC2086
command rsync $RSYNC_ARGS --exclude 'poteto-agent.md' "$SRC/agents/" "$DST_AGENTS/"

if [ "$DRY_RUN" = "--dry-run" ]; then
  exit 0
fi

# Apply opencode transforms only to files that came from upstream.
apply_transforms() {
  perl -pi -e "s/$FROM_CODE/$TO_CODE/g; s/$FROM_JUDGE/$TO_JUDGE/g; s{~/\.cursor/}{~/.opencode/}g" "$1"
}
while IFS= read -r f; do
  rel="${f#$SRC/skills/}"
  dst="$DST_SKILLS/$rel"
  [ -f "$dst" ] || continue
  apply_transforms "$dst"
done < <(command find "$SRC/skills" -type f)
while IFS= read -r f; do
  dst="$DST_AGENTS/$(basename "$f")"
  [ -f "$dst" ] || continue
  apply_transforms "$dst"
done < <(command find "$SRC/agents" -type f ! -name 'poteto-agent.md')

# ponytail: poteto-mode todolist patch, re-applied after every sync so upstream
# overwrites keep the opencode-stricter first line. Delete this block if you
# ever want byte-parity with upstream here.
perl -pi -e 's/\QThe Principles section below grounds every trigger. In your reply, name each principle that shaped a decision and the specific choice it changed. Cite only principles whose leaf SKILL.md you read this session.\E/**Start every multi-step task with a todolist whose first item is to read the Principles section below in full.** The principles ground every trigger here. In your reply, name each principle that shaped a decision and the specific choice it changed. A citation with no decision behind it means you skipped its leaf skill; it must trace to a real choice the leaf\x27s rule drove./' "$DST_SKILLS/poteto-mode/SKILL.md"

echo "synced. protected (untouched): skills/setup-pstack, agents/poteto-agent.md"
echo "next: run /setup-pstack once to regenerate ~/.opencode/rules/pstack-models.mdc for new defaults"
