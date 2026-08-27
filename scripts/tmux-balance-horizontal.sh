#!/usr/bin/env bash
# ルートレベルの横並びペインだけを等幅に揃える。
# 入れ子の縦分割（[ ... ]）は維持する。
#
# 仕組み: pane_top が最小のペインを「最上段」として x 座標でソートし、
# それを「ルート横並びの列」とみなして window_width / 列数 にリサイズする。
# 縦分割の中のペインは width を共有するので、片方をリサイズすれば連動する。

set -e

target="${1:-}"
if [ -n "$target" ]; then
  win_arg=(-t "$target")
else
  win_arg=()
fi

# geometry は一度だけ取得し、tmux client起動の回数を抑える。
pane_data=$(tmux list-panes "${win_arg[@]}" -F '#{window_width} #{pane_top} #{pane_left} #{pane_id}')
width=$(printf '%s\n' "$pane_data" | awk 'NR == 1 { print $1 }')

# pane border title の有無にかかわらず、最小の pane_top を最上段として扱う。
min_top=$(printf '%s\n' "$pane_data" | awk 'NR == 1 || $2 < min { min = $2 } END { print min }')

# 最上段の pane_id を pane_left の昇順で取得
mapfile -t cols < <(
  printf '%s\n' "$pane_data" \
    | awk -v min_top="$min_top" '$2==min_top {print $3, $4}' \
    | sort -n \
    | awk '{print $2}'
)

n=${#cols[@]}
[ "$n" -le 1 ] && exit 0

# ペイン間の境界線を除いた表示領域を、差が最大1文字になるよう分配する。
available=$((width - (n - 1)))
each=$((available / n))
extra=$((available % n))

# 最後の列以外を一度のtmux呼び出しでリサイズ（最後は残り幅で埋まる）。
resize_args=()
for ((i=0; i<n-1; i++)); do
  target_width="$each"
  [ "$i" -lt "$extra" ] && target_width=$((target_width + 1))
  if [ "${#resize_args[@]}" -gt 0 ]; then
    resize_args+=(';' resize-pane)
  else
    resize_args+=(resize-pane)
  fi
  resize_args+=(-t "${cols[$i]}" -x "$target_width")
done

tmux "${resize_args[@]}"
