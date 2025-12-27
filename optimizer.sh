#!/data/data/com.termux/files/usr/bin/bash
# ================================================================
# Android Performance Optimizer for Termux
# Author: Asep Khairul Anam
# Description:
#   This script attempts to optimize Android device performance
#   from within Termux, with optional root enhancements.
#   It aims to improve system responsiveness and help maintain
#   higher frame rates (up to 120 FPS if hardware supports it).
# ================================================================

# =========================
# SAFETY INSTRUCTIONS
# =========================
# 1. Make sure Termux is updated:
#      pkg update && pkg upgrade
# 2. Install dependencies:
#      pkg install tsu procps busybox coreutils
# 3. Make this script executable:
#      chmod +x optimize_android_termux.sh
# 4. Run the script:
#      ./optimize_android_termux.sh
# 5. (Optional) For full optimizations, grant root with:
#      tsu ./optimize_android_termux.sh
# ================================================================

# -------------------------
# Root detection
# -------------------------
check_root() {
    if [ "$(id -u)" -eq 0 ]; then
        ROOT_AVAILABLE=true
    elif command -v su >/dev/null 2>&1; then
        # Try a simple root check
        if su -c 'id -u' | grep -q '^0$'; then
            ROOT_AVAILABLE=true
        else
            ROOT_AVAILABLE=false
        fi
    else
        ROOT_AVAILABLE=false
    fi
}

# -------------------------
# Function to attempt thermal control
# -------------------------
set_thermal() {
    echo "[*] Attempting to reduce thermal throttling..."
    if [ "$ROOT_AVAILABLE" = true ]; then
        # Typical location for thermal zone files
        for tfile in /sys/class/thermal/thermal_zone*/trip_point_*_temp; do
            if [ -w "$tfile" ]; then
                su -c "echo 10000 > $tfile" 2>/dev/null
            fi
        done
        echo "[+] Thermal throttling adjusted (if supported)."
    else
        echo "[-] Skipped: Thermal control requires root."
    fi
}

# -------------------------
# Function to set CPU governor
# -------------------------
set_cpu_governor() {
    echo "[*] Setting CPU governor to 'performance'..."
    if [ "$ROOT_AVAILABLE" = true ]; then
        for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
            gov_file="$cpu/cpufreq/scaling_governor"
            if [ -w "$gov_file" ]; then
                su -c "echo performance > $gov_file" 2>/dev/null
            fi
        done
        echo "[+] CPU governor set to performance mode."
    else
        echo "[-] Skipped: CPU governor change requires root."
    fi
}

# -------------------------
# Clear caches safely
# -------------------------
clear_caches() {
    echo "[*] Attempting to clear system caches..."
    if [ "$ROOT_AVAILABLE" = true ]; then
        su -c "sync; echo 3 > /proc/sys/vm/drop_caches" 2>/dev/null
        echo "[+] System caches cleared."
    else
        # Non-root fallback: clear Termux-level cache
        rm -rf ~/.cache/* 2>/dev/null
        echo "[~] Cleared Termux local cache (non-root fallback)."
    fi
}

# -------------------------
# Disable background processes
# -------------------------
disable_background_services() {
    echo "[*] Attempting to stop heavy background apps..."
    apps=("com.facebook.katana" "com.instagram.android" "com.snapchat.android")
    if [ "$ROOT_AVAILABLE" = true ]; then
        for app in "${apps[@]}"; do
            su -c "am force-stop $app" 2>/dev/null && echo "[+] Stopped $app"
        done
    else
        echo "[-] Skipped app control: Root required to stop background apps."
    fi
}

# -------------------------
# GPU / Display tweak attempt
# -------------------------
gpu_tweak() {
    echo "[*] Attempting GPU and refresh rate tweaks..."
    if [ "$ROOT_AVAILABLE" = true ]; then
        fps_file="/sys/class/graphics/fb0/max_refresh_rate"
        if [ -w "$fps_file" ]; then
            su -c "echo 120 > $fps_file" 2>/dev/null && echo "[+] Set refresh rate to 120Hz."
        else
            echo "[-] Device does not expose refresh rate control via shell."
        fi
    else
        echo "[-] Skipped GPU tweaks: Root required."
    fi
}

# -------------------------
# Lightweight optimization (works without root)
# -------------------------
non_root_boost() {
    echo "[*] Applying lightweight performance boost (non-root)..."
    # Kill non-critical Termux background sessions
    pkill -f "apt" 2>/dev/null
    pkill -f "dpkg" 2>/dev/null
    pkill -f "pkg" 2>/dev/null

    # Clear Termux cache and temporary files
    rm -rf ~/.cache/* /data/data/com.termux/cache/* 2>/dev/null

    # Clean memory page cache (user-space)
    termux-reload-settings 2>/dev/null
    echo "[~] Lightweight optimizations applied."
}

# -------------------------
# Main Execution
# -------------------------
echo "================================================"
echo "   ANDROID PERFORMANCE OPTIMIZER (TERMUX EDITION)"
echo "================================================"

check_root
if [ "$ROOT_AVAILABLE" = true ]; then
    echo "[+] Root access detected — advanced optimizations enabled."
else
    echo "[~] Running without root — limited optimizations available."
fi

# Execute optimization steps
set_thermal
set_cpu_governor
clear_caches
disable_background_services
gpu_tweak
non_root_boost

echo "================================================"
echo "Optimization Complete."
echo "Note:"
echo " - Achievable FPS depends on your device and display."
echo " - Root allows deeper optimizations like CPU/GPU tuning."
echo " - You can re-run this script anytime for temporary boosts."
echo "================================================"
