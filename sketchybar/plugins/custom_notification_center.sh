#!/bin/bash

# Custom Notification Center for SketchyBar
# This script creates a custom notification display using SketchyBar's popup system

# Configuration
POPUP_SCRIPT="$HOME/.dotfiles/sketchybar/plugins/notification_popup.sh"
NOTIF_LOG="/Users/ketiv/.dotfiles/sketchybar/logs/custom_notifications.log"
NOTIF_DATA="/Users/ketiv/.dotfiles/sketchybar/data/notifications.json"

# Ensure data directory exists
mkdir -p "$(dirname "$NOTIF_DATA")"
mkdir -p "$(dirname "$NOTIF_LOG")"

# Initialize notifications data file if it doesn't exist
if [ ! -f "$NOTIF_DATA" ]; then
    echo '{"notifications": [], "last_updated": "'$(date -Iseconds)'"}' > "$NOTIF_DATA"
fi

# Function to add a sample notification for testing
add_sample_notifications() {
    local current_time=$(date -Iseconds)
    cat > "$NOTIF_DATA" << EOF
{
  "notifications": [
    {
      "id": "$(date +%s)001",
      "title": "System Update Available",
      "body": "macOS Sequoia 15.1 is ready to install",
      "app": "Software Update",
      "time": "$current_time",
      "type": "system",
      "read": false
    },
    {
      "id": "$(date +%s)002", 
      "title": "New Message",
      "body": "Hey, how's the SketchyBar setup going?",
      "app": "Messages",
      "time": "$(date -d '5 minutes ago' -Iseconds 2>/dev/null || date -v-5M -Iseconds)",
      "type": "message",
      "read": false
    },
    {
      "id": "$(date +%s)003",
      "title": "Calendar Event",
      "body": "Meeting with design team in 15 minutes",
      "app": "Calendar", 
      "time": "$(date -d '2 minutes ago' -Iseconds 2>/dev/null || date -v-2M -Iseconds)",
      "type": "calendar",
      "read": true
    }
  ],
  "last_updated": "$current_time"
}
EOF
}

# Function to get notification count
get_notification_count() {
    if [ -f "$NOTIF_DATA" ]; then
        python3 -c "
import json
try:
    with open('$NOTIF_DATA', 'r') as f:
        data = json.load(f)
    unread = len([n for n in data['notifications'] if not n.get('read', False)])
    print(unread)
except:
    print(0)
"
    else
        echo "0"
    fi
}

# Function to generate notification list HTML for popup
generate_notification_popup() {
    if [ ! -f "$NOTIF_DATA" ]; then
        add_sample_notifications
    fi
    
    python3 -c "
import json
import datetime

try:
    with open('$NOTIF_DATA', 'r') as f:
        data = json.load(f)
    
    notifications = data['notifications'][:3]  # Show only latest 3
    
    if not notifications:
        print('No notifications')
        exit(0)
    
    for notif in notifications:
        status = '🔴' if not notif.get('read', False) else '⚪'
        app_icon = {
            'system': '⚙️',
            'message': '💬', 
            'calendar': '📅',
            'mail': '✉️'
        }.get(notif.get('type', 'other'), '📱')
        
        time_str = notif.get('time', '')
        try:
            dt = datetime.datetime.fromisoformat(time_str.replace('Z', '+00:00'))
            time_display = dt.strftime('%H:%M')
        except:
            time_display = 'now'
        
        # Truncate title and body for better display
        title = notif['title'][:25] + '...' if len(notif['title']) > 25 else notif['title']
        body = notif['body'][:30] + '...' if len(notif['body']) > 30 else notif['body']
            
        print(f'{status} {app_icon} {title}')
        print(f'  {body} ({time_display})')
        print('')
        
except Exception as e:
    print('Error loading notifications')
"
}

# Main execution based on argument
case "$1" in
    "count")
        get_notification_count
        ;;
    "popup")
        generate_notification_popup
        ;;
    "sample")
        add_sample_notifications
        echo "Sample notifications added"
        ;;
    "clear")
        echo '{"notifications": [], "last_updated": "'$(date -Iseconds)'"}' > "$NOTIF_DATA"
        echo "Notifications cleared"
        ;;
    *)
        echo "Usage: $0 {count|popup|sample|clear}"
        ;;
esac