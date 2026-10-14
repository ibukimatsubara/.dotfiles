on run arguments
    set targetApp to item 1 of arguments
    set targetValue to item 2 of arguments
    if targetApp is "chrome" then
        tell application "Google Chrome"
            set createdWindow to make new window
            set URL of active tab of createdWindow to targetValue
        end tell
    else if targetApp is "finder" then
        tell application "Finder"
            make new Finder window to (POSIX file targetValue as alias)
        end tell
    else
        error "Unsupported window adapter"
    end if
end run
