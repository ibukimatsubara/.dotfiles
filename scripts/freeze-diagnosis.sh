#!/bin/bash
#
# freeze-diagnosis.sh — macOS UI フリーズ診断スクリプト
#
# 使い方:
#   フリーズから復帰した直後に実行:
#     sh ~/.dotfiles/scripts/freeze-diagnosis.sh
#
#   バックグラウンド監視モード (5分間隔でシステム状態を記録):
#     sh ~/.dotfiles/scripts/freeze-diagnosis.sh --monitor
#
#   監視ログの確認:
#     sh ~/.dotfiles/scripts/freeze-diagnosis.sh --review
#

LOG_DIR="$HOME/.local/log/freeze-diagnosis"
mkdir -p "$LOG_DIR"

# --- 即時診断モード ---
run_snapshot() {
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local report="$LOG_DIR/snapshot_${timestamp}.log"

    echo "=== macOS Freeze Diagnosis Report ===" > "$report"
    echo "Date: $(date)" >> "$report"
    echo "Uptime: $(uptime)" >> "$report"
    echo "" >> "$report"

    # 1. メモリプレッシャー
    echo "=== Memory Pressure ===" >> "$report"
    memory_pressure 2>/dev/null >> "$report"
    echo "" >> "$report"

    # 2. VM統計 (スワップ状況)
    echo "=== VM Stats ===" >> "$report"
    vm_stat >> "$report"
    echo "" >> "$report"
    echo "Swap: $(sysctl vm.swapusage 2>/dev/null)" >> "$report"
    echo "" >> "$report"

    # 3. トップメモリ消費プロセス
    echo "=== Top 30 Processes by Memory ===" >> "$report"
    ps aux -m | head -31 >> "$report"
    echo "" >> "$report"

    # 4. トップCPU消費プロセス
    echo "=== Top 20 Processes by CPU ===" >> "$report"
    ps aux -r | head -21 >> "$report"
    echo "" >> "$report"

    # 5. WindowServer の状態
    echo "=== WindowServer ===" >> "$report"
    ps aux | grep "[W]indowServer" >> "$report"
    echo "" >> "$report"

    # 6. 電源アサーション (スリープ妨害)
    echo "=== Power Assertions ===" >> "$report"
    pmset -g assertions 2>/dev/null >> "$report"
    echo "" >> "$report"

    # 7. サーマル状態
    echo "=== Thermal State ===" >> "$report"
    pmset -g therm 2>/dev/null >> "$report"
    echo "" >> "$report"

    # 8. 最近の hang/stall ログ (直近30分)
    echo "=== Recent Hang/Stall Logs (last 30min) ===" >> "$report"
    log show --predicate '(eventMessage contains "hang" OR eventMessage contains "stall" OR eventMessage contains "unresponsive" OR eventMessage contains "watchdog")' \
        --last 30m --style compact 2>/dev/null | tail -50 >> "$report"
    echo "" >> "$report"

    # 9. WindowServer ログ (直近30分)
    echo "=== WindowServer Logs (last 30min) ===" >> "$report"
    log show --predicate 'process == "WindowServer"' --last 30m --style compact 2>/dev/null | tail -30 >> "$report"
    echo "" >> "$report"

    # 10. IOKit HID (入力デバイス) ログ
    echo "=== IOHID Logs (last 30min) ===" >> "$report"
    log show --predicate 'subsystem == "com.apple.iohid"' --last 30m --style compact 2>/dev/null | tail -20 >> "$report"
    echo "" >> "$report"

    # 11. Kensington ドライバ状態
    echo "=== Kensington Driver ===" >> "$report"
    ps aux | grep -i "[k]ensington" >> "$report"
    echo "" >> "$report"

    # 12. ディスプレイ関連の電源イベント (直近1時間)
    echo "=== Display Power Events (last 1h) ===" >> "$report"
    pmset -g log 2>/dev/null | grep -i -e "display" -e "wake" -e "sleep" | tail -20 >> "$report"
    echo "" >> "$report"

    # 13. 最近のスピンダンプ/ハングレポート
    echo "=== Recent Diagnostic Reports ===" >> "$report"
    ls -lt ~/Library/Logs/DiagnosticReports/ 2>/dev/null | head -10 >> "$report"
    echo "" >> "$report"

    # 14. spindump (軽量版 — フリーズの原因プロセスが分かる)
    echo "=== Spindump (lightweight, 3 seconds) ===" >> "$report"
    echo "(Capturing 3-second sample...)" >> "$report"
    sudo spindump 3 -o "$LOG_DIR/spindump_${timestamp}.txt" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "(spindump requires sudo — skipped. Run with sudo for full diagnosis)" >> "$report"
    else
        echo "Saved to: $LOG_DIR/spindump_${timestamp}.txt" >> "$report"
    fi
    echo "" >> "$report"

    echo "=== End of Report ===" >> "$report"
    echo ""
    echo "Diagnosis saved: $report"
    echo ""

    # 簡易サマリーを表示
    echo "--- Quick Summary ---"
    echo "Uptime: $(uptime | sed 's/.*up /up /' | sed 's/,.*//')"
    echo "Swap used: $(sysctl -n vm.swapusage 2>/dev/null | awk '{print $7}')"

    local ws_cpu
    ws_cpu=$(ps aux | grep "[W]indowServer" | awk '{print $3}')
    local ws_time
    ws_time=$(ps aux | grep "[W]indowServer" | awk '{print $10}')
    echo "WindowServer: CPU=${ws_cpu}%, Time=${ws_time}"

    local mem_free
    mem_free=$(memory_pressure 2>/dev/null | grep "free percentage" | awk '{print $NF}')
    echo "Memory free: ${mem_free}"

    local swap_in
    swap_in=$(vm_stat | grep "Swapins" | awk '{print $2}')
    local swap_out
    swap_out=$(vm_stat | grep "Swapouts" | awk '{print $2}')
    echo "Swap I/O: in=${swap_in} out=${swap_out}"

    local assertion_count
    assertion_count=$(pmset -g assertions 2>/dev/null | grep "PreventUserIdleDisplaySleep" | grep -c "1")
    echo "Display sleep prevented: ${assertion_count} assertion(s) active"
    echo ""
    echo "Full report: $report"
}

# --- バックグラウンド監視モード ---
run_monitor() {
    local interval="${1:-300}" # デフォルト5分間隔
    local monitor_log="$LOG_DIR/monitor.log"

    echo "Starting background monitor (interval: ${interval}s)"
    echo "Log file: $monitor_log"
    echo "Stop with: kill $$"
    echo ""

    while true; do
        local timestamp
        timestamp=$(date +"%Y-%m-%d %H:%M:%S")
        local mem_free
        mem_free=$(memory_pressure 2>/dev/null | grep "free percentage" | awk '{print $NF}')
        local swap
        swap=$(sysctl -n vm.swapusage 2>/dev/null | awk '{print "used="$7}')
        local swap_in
        swap_in=$(vm_stat | grep "Swapins" | awk '{print $2}')
        local swap_out
        swap_out=$(vm_stat | grep "Swapouts" | awk '{print $2}')
        local ws_cpu
        ws_cpu=$(ps aux | grep "[W]indowServer" | awk '{print $3}')
        local ws_mem
        ws_mem=$(ps aux | grep "[W]indowServer" | awk '{print $4}')
        local ws_time
        ws_time=$(ps aux | grep "[W]indowServer" | awk '{print $10}')
        local load
        load=$(sysctl -n vm.loadavg 2>/dev/null)
        local pages_compressed
        pages_compressed=$(vm_stat | grep "Pages stored in compressor" | awk '{print $NF}')
        local pages_compressor
        pages_compressor=$(vm_stat | grep "Pages occupied by compressor" | awk '{print $NF}')

        echo "${timestamp} | mem_free=${mem_free} | ${swap} | swap_io=in:${swap_in}/out:${swap_out} | WS_cpu=${ws_cpu}% WS_mem=${ws_mem}% WS_time=${ws_time} | load=${load} | compressed=${pages_compressed} compressor=${pages_compressor}" >> "$monitor_log"

        sleep "$interval"
    done
}

# --- ログレビューモード ---
run_review() {
    echo "=== Monitor Log (last 50 entries) ==="
    if [ -f "$LOG_DIR/monitor.log" ]; then
        tail -50 "$LOG_DIR/monitor.log"
        echo ""
        echo "Total entries: $(wc -l < "$LOG_DIR/monitor.log")"
    else
        echo "No monitor log found. Start monitoring first:"
        echo "  sh ~/.dotfiles/scripts/freeze-diagnosis.sh --monitor &"
    fi

    echo ""
    echo "=== Snapshot Reports ==="
    ls -lt "$LOG_DIR"/snapshot_*.log 2>/dev/null | head -10
    if [ $? -ne 0 ]; then
        echo "No snapshots yet. Run after a freeze:"
        echo "  sh ~/.dotfiles/scripts/freeze-diagnosis.sh"
    fi
}

# --- メイン ---
case "${1:-}" in
    --monitor|-m)
        run_monitor "${2:-300}"
        ;;
    --review|-r)
        run_review
        ;;
    --help|-h)
        echo "Usage:"
        echo "  freeze-diagnosis.sh            # Run snapshot (after freeze)"
        echo "  freeze-diagnosis.sh --monitor   # Start background monitoring"
        echo "  freeze-diagnosis.sh --review    # Review collected logs"
        echo ""
        echo "Log directory: $LOG_DIR"
        ;;
    *)
        run_snapshot
        ;;
esac
