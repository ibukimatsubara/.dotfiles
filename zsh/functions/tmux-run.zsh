# Run command in a new tmux session
# Works both inside and outside of tmux
function tmux-run() {
    local session_name=""
    local command=""
    local detach=true
    
    # Parse arguments - support both quoted and unquoted commands
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
                session_name="$2"
                shift 2
                ;;
            -a|--attach)
                detach=false
                shift
                ;;
            -h|--help)
                echo "Usage: tmux-run [options] <command>"
                echo "Run a command in a new tmux session with Discord notification"
                echo ""
                echo "Options:"
                echo "  -n, --name <name>    Set session name (default: auto-generated)"
                echo "  -a, --attach         Attach to the session immediately"
                echo "  -h, --help          Show this help message"
                echo ""
                echo "Examples:"
                echo "  tmux-run 'npm run dev'"
                echo "  tmux-run npm run dev"
                echo "  tmux-run -n server python -m http.server 8000"
                echo "  tmux-run -a docker-compose up"
                return 0
                ;;
            *)
                # Collect all remaining arguments as the command
                command="$*"
                break
                ;;
        esac
    done
    
    # Check if command is provided
    if [[ -z "$command" ]]; then
        echo "Error: No command provided"
        echo "Use 'tmux-run --help' for usage information"
        return 1
    fi
    
    # Generate session name if not provided
    if [[ -z "$session_name" ]]; then
        # Create a session name based on command and timestamp
        local cmd_base=$(echo "$command" | awk '{print $1}' | xargs basename)
        session_name="${cmd_base}-$(date +%Y%m%d-%H%M%S)"
    fi
    
    # Check if tmux is installed
    if ! command -v tmux &> /dev/null; then
        echo "Error: tmux is not installed"
        return 1
    fi
    
    # Create notification wrapper command with timing
    local start_time=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)
    local script_path="/Users/ketiv/.dotfiles/zsh/functions/tmux-run.zsh"
    local notify_command="start_time='$start_time' && $command && end_time=\$(date -u +%Y-%m-%dT%H:%M:%S.000Z) && source '$script_path' && _tmux_run_send_notification '$session_name' '$command' 'success' \"\$start_time\" \"\$end_time\" || (end_time=\$(date -u +%Y-%m-%dT%H:%M:%S.000Z) && source '$script_path' && _tmux_run_send_notification '$session_name' '$command' 'failed' \"\$start_time\" \"\$end_time\")"
    
    # Check if we're inside tmux
    if [[ -n "$TMUX" ]]; then
        # We're inside tmux, create a new session
        if $detach; then
            tmux new-session -d -s "$session_name" "$notify_command"
            echo "✓ Created detached session with notification: $session_name"
            echo "  Command: $command"
            echo "  Attach with: tmux attach -t $session_name"
        else
            # Create in background then switch
            tmux new-session -d -s "$session_name" "$notify_command"
            tmux switch-client -t "$session_name"
        fi
    else
        # We're outside tmux
        if $detach; then
            tmux new-session -d -s "$session_name" "$notify_command"
            echo "✓ Created detached session with notification: $session_name"
            echo "  Command: $command"
            echo "  Attach with: tmux attach -t $session_name"
        else
            # Attach directly
            tmux new-session -s "$session_name" "$notify_command"
        fi
    fi
}

# Discord notification function for tmux-run
function _tmux_run_send_notification() {
    local session_name="$1"
    local command="$2"
    local cmd_status="$3"
    local start_time="$4"
    local end_time="$5"
    
    # Load config file
    local config_file="$HOME/.config/trun/config"
    if [[ ! -f "$config_file" ]]; then
        echo "Warning: No config file found at $config_file"
        return 1
    fi
    
    source "$config_file"
    
    if [[ -z "$DISCORD_WEBHOOK_URL" ]]; then
        echo "Warning: DISCORD_WEBHOOK_URL not set in config"
        return 1
    fi
    
    local color
    local title
    
    if [[ "$cmd_status" == "success" ]]; then
        color=3066993  # Green
        title="✅ Command Completed Successfully"
    else
        color=15158332  # Red
        title="❌ Command Failed"
    fi
    
    # Calculate duration if both times are available
    local duration_info=""
    if [[ -n "$start_time" && -n "$end_time" ]]; then
        local start_seconds=$(date -j -u -f "%Y-%m-%dT%H:%M:%S.000Z" "$start_time" "+%s" 2>/dev/null || echo "0")
        local end_seconds=$(date -j -u -f "%Y-%m-%dT%H:%M:%S.000Z" "$end_time" "+%s" 2>/dev/null || echo "0")
        if [[ "$start_seconds" -gt 0 && "$end_seconds" -gt 0 ]]; then
            local duration=$((end_seconds - start_seconds))
            duration_info="\\n**Duration:** ${duration}s\\n**Started:** <t:${start_seconds}:t>\\n**Ended:** <t:${end_seconds}:t>"
        fi
    fi

    local message="{
        \"embeds\": [{
            \"title\": \"$title\",
            \"description\": \"**Session:** \`$session_name\`\\n**Command:** \`$command\`$duration_info\",
            \"color\": $color,
            \"footer\": {
                \"text\": \"trun notification\"
            },
            \"timestamp\": \"$end_time\"
        }]
    }"
    
    curl -s -H "Content-Type: application/json" -d "$message" "$DISCORD_WEBHOOK_URL" > /dev/null
}

# Alias for convenience
alias trun='tmux-run'
alias tra='tmux-run -a'

# List running tmux-run sessions
function tmux-run-list() {
    echo "Active tmux sessions:"
    tmux list-sessions 2>/dev/null || echo "No active sessions"
}

# Alias for listing
alias trl='tmux-run-list'

# Kill a tmux-run session
function tmux-run-kill() {
    local session_name="$1"
    
    if [[ -z "$session_name" ]]; then
        echo "Usage: tmux-run-kill <session-name>"
        echo "Use 'tmux-run-list' to see active sessions"
        return 1
    fi
    
    tmux kill-session -t "$session_name" 2>/dev/null
    if [[ $? -eq 0 ]]; then
        echo "✓ Killed session: $session_name"
    else
        echo "Error: Session '$session_name' not found"
        return 1
    fi
}

# Alias for killing
alias trk='tmux-run-kill'

# Attach to a tmux-run session
function tmux-run-attach() {
    local session_name="$1"
    
    if [[ -z "$session_name" ]]; then
        # Show session list and let user choose
        echo "Available sessions:"
        tmux list-sessions 2>/dev/null || { echo "No active sessions"; return 1; }
        echo ""
        echo "Usage: tmux-run-attach <session-name>"
        return 1
    fi
    
    if [[ -n "$TMUX" ]]; then
        # Inside tmux, switch to the session
        tmux switch-client -t "$session_name"
    else
        # Outside tmux, attach to the session
        tmux attach -t "$session_name"
    fi
}

# Alias for attaching
alias trat='tmux-run-attach'