#!/usr/bin/env bash
# ルートレベルの横並びペインだけを等幅に揃える。
# 入れ子の縦分割（[ ... ]）は維持する。
#
# 仕組み: pane_top==0 のペインを「最上段」として x 座標でソートし、
# それを「ルート横並びの列」とみなして window_width / 列数 にリサイズする。
# 縦分割の中のペインは width を共有するので、片方をリサイズすれば連動する。

set -e

target="${1:-}"
if [ -n "$target" ]; then
  win_arg=(-t "$target")
else
  win_arg=()
fi

width=$(tmux display -p "${win_arg[@]}" '#{window_width}')

# pane_top==0 の pane_id を pane_left の昇順で取得
mapfile -t cols < <(
  tmux list-panes "${win_arg[@]}" -F '#{pane_top} #{pane_left} #{pane_id}' \
    | awk '$1==0 {print $2, $3}' \
    | sort -n \
    | awk '{print $2}'
)

n=${#cols[@]}
[ "$n" -le 1 ] && exit 0

each=$((width / n))

# 最後の列以外をリサイズ（最後は残り幅で自動的に埋まる）
for ((i=0; i<n-1; i++)); do
  tmux resize-pane -t "${cols[$i]}" -x "$each"
done
