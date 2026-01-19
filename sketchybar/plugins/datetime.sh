#!/bin/bash

# 日付と時刻を表示 (01/19 Sun 14:43 形式)
DATETIME=$(date "+%m/%d %a %H:%M")

sketchybar --set $NAME label="$DATETIME"
