# opencode-pstack

Cursor の [pstack](https://github.com/cursor/plugins/tree/main/pstack) skill と agent を opencode で使うための同期ツールです。手動コピー不要。

pstack は公式には Cursor の plugin のため、opencode で使うには plugins レポを `git pull` して `~/.config/opencode/skills` と `~/.config/opencode/agents` に手でコピーする必要がありました。このレポはそれを1コマンド化し、さらに opencode の plugin として session 内から agent が実行できるようにします。

## 内容

- `scripts/sync-pstack.sh` — 同期 script。本体。single source of truth はこれ。
- `plugins/pstack-sync.ts` — script を `pstack_sync` tool として公開する薄い opencode plugin。logic は持たない。

## 動作環境

- `git` と POSIX 道具(`cp`、`awk`、`find`)のみ。macOS・Linux 標準搭載。`rsync` も `perl` も不要。
- opencode の `~/.config/opencode/package.json` に `@opencode-ai/plugin`(`pstack_sync` tool を使う場合のみ)

## Install

1. plugins レポから `pstack` だけ sparse checkout(全体は不要):

```bash
git clone --filter=blob:none --sparse https://github.com/cursor/plugins.git ~/.local/share/cursor-plugins
git -C ~/.local/share/cursor-plugins sparse-checkout set pstack
```

2. 2ファイルを opencode config にコピー(このレポと同じ配置):

```bash
cp plugins/pstack-sync.ts ~/.config/opencode/plugins/
cp scripts/sync-pstack.sh ~/.config/opencode/scripts/
chmod +x ~/.config/opencode/scripts/sync-pstack.sh
```

3. `sync-pstack.sh` 冒頭の model 対応表を自分の環境に合わせる:

```bash
FROM_CODE="grok-4.7-xhigh-fast"; TO_CODE="grok-4.6-fast-xhigh"
FROM_JUDGE="claude-opus-5-5-xhigh"; TO_JUDGE="claude-fable-5-1-thinking-max"
```

4. opencode を再起動(plugin は起動時に読込)。

## 使い方

opencode 内では頼むだけ:

```
pstack 同期して
```

agent が `pstack_sync` tool を呼びます。`dry_run`(確認のみ)と `no_pull`(手元 checkout のまま同期)が使えます。

terminal から直接も可:

```bash
~/.config/opencode/scripts/sync-pstack.sh
~/.config/opencode/scripts/sync-pstack.sh --dry-run   # 確認のみ
~/.config/opencode/scripts/sync-pstack.sh --no-pull    # git pull しない
PSTACK_ROOT=/path/to/plugins sync-pstack.sh            # checkout 場所を指定
SKIP_PULL=1 sync-pstack.sh                             # --no-pull と同じ
```

## 同期の中身

1. checkout を `git pull --ff-only`(`--no-pull` / `SKIP_PULL=1` で省略)。
2. `pstack/skills/` → `~/.config/opencode/skills/` に rsync。`setup-pstack` は opencode 用に全面書換のため除外(上書きしない)。
3. `pstack/agents/` → `~/.config/opencode/agents/` に rsync。`poteto-agent.md` は opencode 用 resume 動作のため除外(上書きしない)。
4. 同期したファイルにのみ opencode 変換を適用:model slug 対応表、`~/.cursor/` → `~/.opencode/`、poteto-mode の厳しめ todolist 先頭行。
5. 削除は一切しないため、opencode 固有の skill(twg 等、自作含む)は毎回残ります。

script は idempotent です。再実行は何度でも同じ状態に収束します。

同期後は `/setup-pstack` を1回実行し、`~/.opencode/rules/pstack-models.mdc` に新しい role default を反映してください。

## License

MIT
