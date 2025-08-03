# Image display function for WezTerm
# Supports local files, URLs, and SSH remote files

icat() {
    local file="$1"
    local width="${2:-auto}"
    local height="${3:-auto}"
    
    if [[ -z "$file" ]]; then
        echo "Usage: icat <file|url|ssh:user@host:path> [width] [height]"
        echo "Examples:"
        echo "  icat image.png"
        echo "  icat https://example.com/image.jpg"
        echo "  icat ssh:user@server:/path/to/image.png"
        echo "  icat image.png 50% 50%"
        return 1
    fi
    
    # Check if we're in WezTerm
    if [[ "$TERM_PROGRAM" != "WezTerm" ]]; then
        echo "Warning: icat works best in WezTerm terminal"
    fi
    
    # Handle SSH remote files
    if [[ "$file" =~ ^ssh:(.+):(.+)$ ]]; then
        local ssh_host="${match[1]}"
        local remote_path="${match[2]}"
        local temp_file="/tmp/icat_$(basename "$remote_path")_$$"
        
        echo "Downloading from $ssh_host:$remote_path..."
        if scp "$ssh_host:$remote_path" "$temp_file" >/dev/null 2>&1; then
            file="$temp_file"
        else
            echo "Error: Failed to download file from $ssh_host:$remote_path"
            return 1
        fi
    fi
    
    # Handle URLs
    if [[ "$file" =~ ^https?:// ]]; then
        local temp_file="/tmp/icat_$(basename "$file")_$$"
        echo "Downloading from $file..."
        if curl -s -o "$temp_file" "$file"; then
            file="$temp_file"
        else
            echo "Error: Failed to download file from $file"
            return 1
        fi
    fi
    
    # Check if file exists
    if [[ ! -f "$file" ]]; then
        echo "Error: File '$file' not found"
        return 1
    fi
    
    # Check if file is an image
    local file_type=$(file --mime-type "$file" 2>/dev/null | cut -d: -f2 | tr -d ' ')
    if [[ ! "$file_type" =~ ^image/ ]]; then
        echo "Warning: File may not be an image (detected: $file_type)"
    fi
    
    # Display image using WezTerm's image protocol
    if command -v wezterm >/dev/null 2>&1; then
        wezterm imgcat --width "$width" --height "$height" "$file"
    else
        # Fallback to other image viewers
        if command -v kitty >/dev/null 2>&1; then
            kitty +kitten icat "$file"
        elif command -v imgcat >/dev/null 2>&1; then
            imgcat "$file"
        else
            echo "No suitable image viewer found. Install wezterm or kitty for best experience."
            return 1
        fi
    fi
    
    # Clean up temp files
    if [[ "$file" =~ ^/tmp/icat_ ]]; then
        rm -f "$file"
    fi
}

# Alias for convenience
alias img='icat'
alias showimg='icat'