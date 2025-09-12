#!/bin/bash

echo "=== Notification Count Debug ==="
echo "Date: $(date)"
echo ""

echo "Method 1 - lsappinfo (Notification Center):"
METHOD1=$(lsappinfo info -only StatusLabel $(lsappinfo find LSDisplayName="Notification Center") | grep -o '"StatusLabel"="[0-9]*"' | grep -o '[0-9]*' | head -1 2>/dev/null)
echo "Result: '$METHOD1'"
echo ""

echo "Method 2 - lsappinfo (NotificationCenter):"
METHOD2=$(lsappinfo info -only StatusLabel $(lsappinfo find LSDisplayName="NotificationCenter") | grep -o '"StatusLabel"="[0-9]*"' | grep -o '[0-9]*' | head -1 2>/dev/null)
echo "Result: '$METHOD2'"
echo ""

echo "Method 3 - sqlite database:"
METHOD3=$(sqlite3 "$HOME/Library/Application Support/com.apple.notificationcenterui/db2/db" "SELECT COUNT(*) FROM notifications WHERE shown = 0;" 2>/dev/null || echo "DB_NOT_ACCESSIBLE")
echo "Result: '$METHOD3'"
echo ""

echo "Method 4 - system log (last 10m):"
METHOD4=$(log show --predicate 'subsystem == "com.apple.usernotifications" AND eventMessage CONTAINS "deliver"' --style compact --last 10m 2>/dev/null | wc -l | tr -d ' ' || echo "LOG_NOT_ACCESSIBLE")
echo "Result: '$METHOD4'"
echo ""

echo "Method 5 - AppleScript UI:"
METHOD5=$(osascript -e '
try
    tell application "System Events"
        tell process "NotificationCenter"
            if exists window 1 then
                set notifCount to count of UI elements of window 1
                return notifCount
            end if
        end tell
    end tell
    return 0
on error
    return "APPLESCRIPT_ERROR"
end try' 2>/dev/null || echo "APPLESCRIPT_NOT_ACCESSIBLE")
echo "Result: '$METHOD5'"
echo ""

echo "List of running processes with 'notification' in name:"
ps aux | grep -i notification | grep -v grep
echo ""

echo "Check notification center processes:"
lsappinfo list | grep -i notification
echo ""

echo "Check control center processes:"
lsappinfo list | grep -i control