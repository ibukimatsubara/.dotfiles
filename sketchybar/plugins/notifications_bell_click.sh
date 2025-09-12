#!/bin/bash

# Log directory
LOG_DIR="$HOME/.dotfiles/sketchybar/logs"
LOG_FILE="$LOG_DIR/notifications_bell.log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Log the click event
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Notification bell clicked" >> "$LOG_FILE"

# Get macOS version for compatibility
MACOS_VERSION=$(sw_vers -productVersion)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] macOS Version: $MACOS_VERSION" >> "$LOG_FILE"

# Method 1: Try to access notification history/list (macOS 15+)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Trying notification history access..." >> "$LOG_FILE"
if osascript -e '
tell application "System Events"
    try
        -- Try to access the notification center widget area
        tell process "NotificationCenter"
            if exists window 1 then
                perform action "AXRaise" of window 1
                return true
            end if
        end tell
        
        -- Alternative: try to show notification widget
        do shell script "open \"x-apple.widget://notifications\""
        return true
    on error
        try
            -- Fallback: use swipe gesture to show notification center
            set screenBounds to bounds of desktop
            set screenWidth to item 3 of screenBounds
            set screenHeight to item 4 of screenBounds
            
            -- Two-finger swipe from right edge simulation
            click at {screenWidth - 2, screenHeight / 2}
            delay 0.2
            return true
        on error
            return false
        end try
    end try
end tell' 2>> "$LOG_FILE"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Notification history method succeeded" >> "$LOG_FILE"
    exit 0
fi

# Method 2: Try command line notification access
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Trying command line approach..." >> "$LOG_FILE"
if which terminal-notifier >/dev/null 2>&1; then
    terminal-notifier -list 2>> "$LOG_FILE" && echo "[$(date '+%Y-%m-%d %H:%M:%S')] Command line method succeeded" >> "$LOG_FILE" && exit 0
fi

# Method 3: Direct notification database access (fallback)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Trying direct database access..." >> "$LOG_FILE"
if osascript -e '
tell application "System Events"
    try
        -- Try to open notification center using coordinate approach
        set screenBounds to bounds of desktop
        set screenWidth to item 3 of screenBounds
        
        -- Click on the very top-right corner where notifications usually are
        click at {screenWidth - 5, 5}
        delay 0.5
        
        -- If that opens control center, try to find notification section
        tell process "ControlCenter"
            if exists window 1 then
                try
                    click button "Notifications" of window 1
                    return true
                on error
                    -- If no notification button, just show what opened
                    return true
                end try
            end if
        end tell
        return true
    on error
        return false
    end try
end tell' 2>> "$LOG_FILE"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Coordinate click method succeeded" >> "$LOG_FILE"
    exit 0
fi

# Method 3: System Settings approach
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Trying System Settings..." >> "$LOG_FILE"
if open "x-apple.systempreferences:com.apple.preference.notifications" 2>> "$LOG_FILE"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] System Settings method succeeded" >> "$LOG_FILE"
    exit 0
fi

# Method 3: Direct bundle (may not work on newer macOS)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Trying direct bundle..." >> "$LOG_FILE"
if open -b com.apple.notificationcenterui 2>> "$LOG_FILE"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Bundle method succeeded" >> "$LOG_FILE"
    exit 0
fi

# Method 4: Keyboard shortcut simulation
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Trying keyboard shortcut..." >> "$LOG_FILE"
if osascript -e '
tell application "System Events"
    try
        -- Simulate clicking on the top-right corner where notification center usually is
        click at {screen of (primary screen)
        set screenBounds to bounds of desktop
        set screenWidth to item 3 of screenBounds
        click at {screenWidth - 10, 10}
        return true
    on error
        return false
    end try
end tell' 2>> "$LOG_FILE"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Keyboard shortcut method succeeded" >> "$LOG_FILE"
    exit 0
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] All methods failed" >> "$LOG_FILE"