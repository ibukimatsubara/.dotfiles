# SSH wrapper function to set hostname
ssh() {
    # Extract hostname from first non-option argument
    local host=""
    for arg in "$@"; do
        case "$arg" in
            -*) continue ;;
            *@*) host="${arg#*@}" ; break ;;
            *) host="$arg" ; break ;;
        esac
    done
    
    # Set environment variable and execute ssh
    if [ -n "$host" ]; then
        SSH_HOST="$host" command ssh "$@"
    else
        command ssh "$@"
    fi
}