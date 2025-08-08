# Run command in a new tmux session
# Works both inside and outside of tmux
function tmux-run() {
    local session_name=""
    local command=""
    local detach=true
    
    # Parse arguments
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
                echo "Run a command in a new tmux session"
                echo ""
                echo "Options:"
                echo "  -n, --name <name>    Set session name (default: auto-generated)"
                echo "  -a, --attach         Attach to the session immediately"
                echo "  -h, --help          Show this help message"
                echo ""
                echo "Examples:"
                echo "  tmux-run 'npm run dev'"
                echo "  tmux-run -n server 'python -m http.server 8000'"
                echo "  tmux-run -a 'docker-compose up'"
                return 0
                ;;
            *)
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
    
    # Check if we're inside tmux
    if [[ -n "$TMUX" ]]; then
        # We're inside tmux, create a new session
        if $detach; then
            tmux new-session -d -s "$session_name" "$command"
            echo "✓ Created detached session: $session_name"
            echo "  Command: $command"
            echo "  Attach with: tmux attach -t $session_name"
        else
            # Create in background then switch
            tmux new-session -d -s "$session_name" "$command"
            tmux switch-client -t "$session_name"
        fi
    else
        # We're outside tmux
        if $detach; then
            tmux new-session -d -s "$session_name" "$command"
            echo "✓ Created detached session: $session_name"
            echo "  Command: $command"
            echo "  Attach with: tmux attach -t $session_name"
        else
            # Attach directly
            tmux new-session -s "$session_name" "$command"
        fi
    fi
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