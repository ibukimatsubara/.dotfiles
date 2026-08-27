#!/bin/bash

set -u
umask 077

readonly PREVIEW_DIR="${SVM_OPEN_DEST:-$HOME/Downloads/svm-preview}"
readonly FALLBACK_DIR="${TAILDROP_FALLBACK_DIR:-$HOME/Downloads/Taildrop}"
readonly STATE_DIR="${SVM_OPEN_STATE_DIR:-$HOME/Library/Caches/com.local.taildrop-open}"
readonly STAGING_DIR="$STATE_DIR/incoming"
readonly LOG_FILE="${SVM_OPEN_LOG:-$HOME/Library/Logs/svm-open-receiver.log}"

find_tailscale_cli() {
    if command -v tailscale >/dev/null 2>&1; then
        command -v tailscale
    elif [ -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]; then
        printf '%s\n' /Applications/Tailscale.app/Contents/MacOS/Tailscale
    else
        return 1
    fi
}

log_message() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
}

move_regular_taildrop() {
    source_path="$1"
    file_name="${source_path##*/}"
    destination="$FALLBACK_DIR/$file_name"

    if [ -e "$destination" ]; then
        destination="$FALLBACK_DIR/$(date +%Y%m%d-%H%M%S)-$$-$file_name"
    fi

    /bin/mv "$source_path" "$destination"
    log_message "saved regular Taildrop file: ${destination##*/}"
}

process_received_files() {
    shopt -s nullglob

    for received_path in "$STAGING_DIR"/* "$STAGING_DIR"/.[!.]* "$STAGING_DIR"/..?*; do
        [ -f "$received_path" ] || continue

        received_name="${received_path##*/}"
        case "$received_name" in
            svm-open--*--*)
                preview_name="${received_name#svm-open--}"
                preview_name="${preview_name#*--}"
                ;;
            *)
                move_regular_taildrop "$received_path"
                continue
                ;;
        esac

        case "$preview_name" in
            ""|"."|".."|*/*)
                log_message "rejected invalid preview filename"
                move_regular_taildrop "$received_path"
                continue
                ;;
        esac

        preview_path="$PREVIEW_DIR/$preview_name"
        /bin/mv -f "$received_path" "$preview_path"

        extension="${preview_name##*.}"
        extension="$(printf '%s' "$extension" | tr '[:upper:]' '[:lower:]')"
        case "$extension" in
            pptx|pdf|md|markdown|html|htm|docx|xlsx|png|jpg|jpeg|gif|webp|svg|txt|csv)
                if /usr/bin/open "$preview_path"; then
                    log_message "opened preview: $preview_name"
                else
                    log_message "failed to open preview: $preview_name"
                fi
                ;;
            *)
                log_message "saved preview without opening unsupported extension: $preview_name"
                ;;
        esac
    done
}

mkdir -p "$PREVIEW_DIR" "$FALLBACK_DIR" "$STAGING_DIR" "$(dirname "$LOG_FILE")"

if ! tailscale_cli="$(find_tailscale_cli)"; then
    log_message "Tailscale CLI not found; receiver stopped"
    exit 1
fi

log_message "receiver started"
while true; do
    if TAILSCALE_BE_CLI=1 "$tailscale_cli" file get --wait --conflict=rename "$STAGING_DIR" >> "$LOG_FILE" 2>&1; then
        process_received_files
    else
        log_message "Taildrop receive failed; retrying in 5 seconds"
        sleep 5
    fi
done
