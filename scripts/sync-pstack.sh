#!/usr/bin/env bash
# Sync pstack (cursor/plugins repo) -> opencode skills/agents.
# Idempotent: safe to re-run. Never deletes opencode-only skills.
# Protected (opencode custom, never overwritten): skills/setup-pstack, agents/poteto-agent.md
# Transforms applied after copy: model slugs + ~/.cursor/ paths -> opencode values,
# plus the poteto-mode todolist patch.
# Needs only git + POSIX tools (cp, awk, find). No rsync, no perl.
set -euo pipefail

ROOT="${PSTACK_ROOT:-$HOME/.local/share/cursor-plugins}"
SRC="$ROOT/pstack"
DST_SKILLS="$HOME/.config/opencode/skills"
DST_AGENTS="$HOME/.config/opencode/agents"
# Literal string mapping: upstream (Cursor) -> your opencode values.
# Edit these to match the models you actually have.
FROM_CODE="grok-4.7-xhigh-fast"; TO_CODE="grok-4.6-fast-xhigh"
FROM_JUDGE="claude-opus-5-5-xhigh"; TO_JUDGE="claude-fable-5-1-thinking-max"
FROM_PATH="~/.cursor/"; TO_PATH="~/.opencode/"
# ponytail: opencode-stricter todolist first line. Empty FROM_TODOLIST for
# byte-parity with upstream here.
FROM_TODOLIST="The Principles section below grounds every trigger. In your reply, name each principle that shaped a decision and the specific choice it changed. Cite only principles whose leaf SKILL.md you read this session."
TO_TODOLIST="**Start every multi-step task with a todolist whose first item is to read the Principles section below in full.** The principles ground every trigger here. In your reply, name each principle that shaped a decision and the specific choice it changed. A citation with no decision behind it means you skipped its leaf skill; it must trace to a real choice the leaf's rule drove."
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

# Copy src/ into dst/, skipping one excluded name. cp -R merges into existing
# directories and nothing is deleted, so opencode-only files survive.
sync_dir() {
  mkdir -p "$2"
  for e in "$1"* "$1".*; do
    case "$(basename "$e")" in
      .|..) continue ;;
      "$3") continue ;;
    esac
    [ -e "$e" ] || continue
    if [ -n "$DRY_RUN" ]; then
      echo "would sync: $e -> $2/"
    else
      cp -R "$e" "$2/"
    fi
  done
}

# Literal (non-regex) multi-pair replacement, one awk pass per file.
apply_transforms() {
  awk -v c1="$FROM_CODE" -v c2="$TO_CODE" \
      -v j1="$FROM_JUDGE" -v j2="$TO_JUDGE" \
      -v p1="$FROM_PATH" -v p2="$TO_PATH" \
      -v t1="$FROM_TODOLIST" -v t2="$TO_TODOLIST" '
    function rep(s, a, b,   i, o) {
      if (a == "") return s
      o = ""
      while ((i = index(s, a)) > 0) { o = o substr(s, 1, i-1) b; s = substr(s, i + length(a)) }
      return o s
    }
    { print rep(rep(rep(rep($0, c1, c2), j1, j2), p1, p2), t1, t2) }
  ' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}

if [ -z "$DRY_RUN" ]; then
  if [ "$DO_PULL" = "1" ] && [ -z "${SKIP_PULL:-}" ]; then
    git -C "$ROOT" pull --ff-only
  else
    echo "skipping git pull"
  fi
else
  echo "dry-run: no changes will be written"
fi

sync_dir "$SRC/skills/" "$DST_SKILLS" "setup-pstack"
sync_dir "$SRC/agents/" "$DST_AGENTS" "poteto-agent.md"

if [ -n "$DRY_RUN" ]; then
  exit 0
fi

# Apply opencode transforms only to files that came from upstream.
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

echo "synced. protected (untouched): skills/setup-pstack, agents/poteto-agent.md"
echo "next: run /setup-pstack once to regenerate ~/.opencode/rules/pstack-models.mdc for new defaults"
