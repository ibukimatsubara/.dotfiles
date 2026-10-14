# Associate local, directly launched agents with the focused Ghostty window.
_agent_workspace_launch() {
  local executable="$1"
  shift
  local row window_id bundle_id origin_pid
  local routing_bin="$HOME/.dotfiles/scripts/agent-bin"
  local real_code="${AGENT_REAL_CODE:-$(whence -p code)}"

  # Nested agents retain their parent's identity instead of taking global focus.
  if [[ "$AGENT_ORIGIN_WINDOW_ID" == <-> && "$AGENT_ORIGIN_APP_PID" == <-> ]]; then
    AGENT_REAL_CODE="$real_code" PATH="$routing_bin:$PATH" command "$executable" "$@"
    return $?
  fi

  if [[ "$TERM_PROGRAM" != ghostty || -n "$TMUX" || -n "$SSH_CONNECTION" || ! -t 0 ]]; then
    command "$executable" "$@"
    return $?
  fi

  row="$(aerospace list-windows --focused --format '%{window-id}|%{app-bundle-id}|%{app-pid}' 2>/dev/null)"
  IFS='|' read -r window_id bundle_id origin_pid <<< "$row"
  if [[ "$bundle_id" != com.mitchellh.ghostty || "$window_id" != <-> || "$origin_pid" != <-> ]]; then
    print -u2 'agent-workspace: Ghostty origin unavailable; launching without window routing.'
    command "$executable" "$@"
    return $?
  fi

  AGENT_ORIGIN_WINDOW_ID="$window_id" \
  AGENT_ORIGIN_APP_PID="$origin_pid" \
  AGENT_REAL_CODE="$real_code" \
  PATH="$routing_bin:$PATH" \
    command "$executable" "$@"
}

codex() { _agent_workspace_launch codex "$@"; }
claude() { _agent_workspace_launch claude "$@"; }
dsh() { _agent_workspace_launch dsh "$@"; }
deepseek() { _agent_workspace_launch deepseek "$@"; }
harness() { _agent_workspace_launch harness "$@"; }
