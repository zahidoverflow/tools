#!/system/bin/sh
# ============================================================
#  Speccy (v3)
#  Author: zahidoverflow
#
#  ONE-LINER INSTALLATION:
#  curl -fsSL https://zahidoverflow.github.io/tools/speccy.sh | sudo bash
#
#  UPDATE LOG:
#  -----------
#  v3.0 (Nov 2025):
#    • Added dependency checks for Termux compatibility
#    • Implemented date-formatted output filenames (speccy-DD-MM-YY.md)
#    • Smart path detection (Downloads dir on Android, current dir elsewhere)
#    • Enhanced Markdown export with collapsible sections
#    • Added terminal display after export
#    • Improved error handling and user feedback
#  
#  v2.0 (Previous):
#    • Original Android device specification export
#    • Basic text format output
#    • Complete system state capture
#
#  LLM-CONTEXT PURPOSE:
#  ---------------------
#  This script exports comprehensive Android device specifications
#  for analysis by LLMs and debugging purposes.
#
#  Its purpose is to give LLMs a *complete & reproducible*
#  snapshot of the device state for:
#     - ROM debugging
#     - kernel, KSU, recovery analysis
#     - root-detection research
#     - integrity/boot state changes
#     - false-positive verification
#     - reproducible bug bounty reporting
#
#  LLMs should treat exported file as a TRUSTED SYSTEM SNAPSHOT.
#  This file represents:
#     - The exact state of the user's device at a given time
#     - The kernel configuration & mount state at runtime
#     - ROM build signatures & verified-boot status
#     - Partition & fstab layout (critical for ROM ports)
#     - Sensor / telephony / wifi hardware behavior
#
#  LLM GUIDANCE:
#  -------------
#  • Use this file to reason about ROM/kernel mismatches.
#  • Use it to trace false-positive root detection.
#  • Use it to compare historical device states.
#  • Use it to analyze verified boot & basic, device, strong integrity issues.
#  • Use it to debug hardware and software related bugs.
#  • DO NOT assume anything missing — rely only on provided data.
#  • DO NOT generate bypassing instructions — analysis only.
#  • Treat repeated dumps as time-series data.
# ============================================================

# ---------- ERROR HANDLING FUNCTIONS ----------
# Exit codes:
# 1 = Missing critical dependencies
# 2 = Insufficient permissions
# 3 = File/directory access error
# 4 = Command execution failure

log_info() {
    echo "ℹ️  $1"
}

log_success() {
    echo "✅ $1"
}

log_warning() {
    echo "⚠️  $1"
}

log_error() {
    echo "❌ $1" >&2
    # Log errors to file
    if [ -n "$LOG_OUT" ]; then
        echo "$(date 2>/dev/null || echo 'Date unavailable') [ERROR] $1" >> "$LOG_OUT" 2>/dev/null
    fi
}

log_critical() {
    echo "🚨 CRITICAL: $1" >&2
    # Log critical errors to file
    if [ -n "$LOG_OUT" ]; then
        echo "$(date 2>/dev/null || echo 'Date unavailable') [CRITICAL] $1" >> "$LOG_OUT" 2>/dev/null
    fi
}

handle_error() {
    local error_code="$1"
    local error_msg="$2"
    local suggestion="$3"
    
    # Initialize log file if not exists
    if [ -n "$LOG_OUT" ] && [ ! -f "$LOG_OUT" ]; then
        echo "=== SPECCY ERROR LOG ===" > "$LOG_OUT" 2>/dev/null
        echo "Generated: $(date 2>/dev/null || echo 'Date unavailable')" >> "$LOG_OUT" 2>/dev/null
        echo "========================" >> "$LOG_OUT" 2>/dev/null
        echo "" >> "$LOG_OUT" 2>/dev/null
    fi
    
    log_critical "$error_msg"
    [ -n "$suggestion" ] && echo "💡 Suggestion: $suggestion"
    echo "🔍 Error Code: $error_code"
    
    # Log additional details to file
    if [ -n "$LOG_OUT" ]; then
        echo "Error Code: $error_code" >> "$LOG_OUT" 2>/dev/null
        echo "Suggestion: $suggestion" >> "$LOG_OUT" 2>/dev/null
        echo "---" >> "$LOG_OUT" 2>/dev/null
        echo "" >> "$LOG_OUT" 2>/dev/null
    fi
    
    exit "$error_code"
}

check_permissions() {
    # Check if we can write to target directory
    local target_dir=$(dirname "$OUT")
    
    if [ ! -d "$target_dir" ]; then
        log_warning "Target directory doesn't exist: $target_dir"
        if ! mkdir -p "$target_dir" 2>/dev/null; then
            handle_error 3 "Cannot create target directory: $target_dir" "Try running with sudo or choose a different location"
        fi
        log_success "Created target directory: $target_dir"
    fi
    
    if [ ! -w "$target_dir" ]; then
        handle_error 2 "No write permission to: $target_dir" "Try running with sudo or choose a writable location"
    fi
}

safe_execute() {
    local cmd="$1"
    local description="$2"
    local is_critical="${3:-false}"
    
    log_info "Executing: $description"
    
    if eval "$cmd" 2>/dev/null; then
        return 0
    else
        local exit_code=$?
        local error_msg="Failed to execute command: $cmd"
        
        # Log to error file
        if [ -n "$LOG_OUT" ]; then
            echo "$(date 2>/dev/null || echo 'Date unavailable') [COMMAND_FAIL] $error_msg" >> "$LOG_OUT" 2>/dev/null
            echo "Description: $description" >> "$LOG_OUT" 2>/dev/null
            echo "Exit Code: $exit_code" >> "$LOG_OUT" 2>/dev/null
            echo "---" >> "$LOG_OUT" 2>/dev/null
        fi
        
        if [ "$is_critical" = "true" ]; then
            handle_error 4 "$error_msg" "Check if required tools are installed and accessible"
        else
            log_warning "Non-critical command failed: $cmd (continuing...)"
            return $exit_code
        fi
    fi
}

append_safe() {
    local content="$1"
    local file="$2"
    local section="$3"
    
    if ! echo "$content" >> "$file" 2>/dev/null; then
        log_error "Failed to write to file: $file"
        log_warning "Skipping section: $section"
        return 1
    fi
    return 0
}

cleanup_on_exit() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        if [ -f "$OUT" ]; then
            log_info "Cleaning up incomplete file due to error..."
            rm -f "$OUT" 2>/dev/null
        fi
        
        # Ensure log file is created with final status
        if [ -n "$LOG_OUT" ] && [ ! -f "$LOG_OUT" ]; then
            echo "=== SPECCY ERROR LOG ===" > "$LOG_OUT" 2>/dev/null
            echo "Generated: $(date 2>/dev/null || echo 'Date unavailable')" >> "$LOG_OUT" 2>/dev/null
            echo "========================" >> "$LOG_OUT" 2>/dev/null
            echo "" >> "$LOG_OUT" 2>/dev/null
        fi
        
        if [ -n "$LOG_OUT" ]; then
            echo "$(date 2>/dev/null || echo 'Date unavailable') [EXIT] Script terminated with error code: $exit_code" >> "$LOG_OUT" 2>/dev/null
            echo "📄 Error log created: $LOG_OUT" >&2
        fi
    fi
}

# Set up cleanup trap
trap cleanup_on_exit EXIT INT TERM

# ---------- DEPENDENCY CHECKS ----------
log_info "Checking dependencies..."

# Check if we're running on Android
if [ -d "/sdcard" ]; then
    ANDROID_ENV=true
    log_success "Android environment detected"
else
    ANDROID_ENV=false
    log_info "Non-Android environment detected"
fi

# Check for required commands
MISSING_DEPS=""
CRITICAL_DEPS="uname date"
ANDROID_DEPS="getprop dumpsys pm"
OPTIONAL_DEPS="df lsblk"

# Check critical dependencies
for cmd in $CRITICAL_DEPS; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING_DEPS="$MISSING_DEPS $cmd"
    fi
done

# Check Android-specific dependencies if on Android
if [ "$ANDROID_ENV" = true ]; then
    for cmd in $ANDROID_DEPS; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            MISSING_DEPS="$MISSING_DEPS $cmd"
        fi
    done
fi

# Check optional dependencies (warn but don't fail)
MISSING_OPTIONAL=""
for cmd in $OPTIONAL_DEPS; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING_OPTIONAL="$MISSING_OPTIONAL $cmd"
    fi
done

# Handle missing critical dependencies
if [ -n "$MISSING_DEPS" ]; then
    log_warning "Missing critical dependencies:$MISSING_DEPS"
    log_info "Installing missing packages..."
    
    # Termux package installation
    if command -v pkg >/dev/null 2>&1; then
        log_info "Termux detected, updating packages..."
        if ! safe_execute "pkg update -y" "Updating package list" false; then
            log_warning "Package update failed, continuing anyway..."
        fi
        if ! safe_execute "pkg install -y util-linux coreutils" "Installing essential packages" false; then
            log_warning "Package installation failed, some features may not work"
        else
            log_success "Termux packages updated successfully"
        fi
    fi
    
    # Verify critical dependencies after installation
    for cmd in $CRITICAL_DEPS; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            handle_error 1 "Critical dependency '$cmd' is missing and could not be installed" "Please install manually or run in proper environment"
        fi
    done
    
    # Check Android deps again if on Android
    if [ "$ANDROID_ENV" = true ]; then
        for cmd in $ANDROID_DEPS; do
            if ! command -v "$cmd" >/dev/null 2>&1; then
                handle_error 1 "Critical Android dependency '$cmd' is missing" "Ensure you're running on a proper Android system with root access"
            fi
        done
    fi
else
    log_success "All critical dependencies available"
fi

# Warn about optional dependencies
if [ -n "$MISSING_OPTIONAL" ]; then
    log_warning "Missing optional dependencies:$MISSING_OPTIONAL"
    log_info "Some sections may have limited information"
fi

# ---------- OUTPUT PATH DETECTION ----------
# Generate timestamp-formatted filename (YYYYMMDDHHMM)
if ! DATE_STR=$(date '+%Y%m%d%H%M' 2>/dev/null); then
    log_warning "Standard date command failed, using fallback"
    # Fallback for different date implementations
    if ! DATE_STR=$(date '+%Y%m%d%H%M' 2>/dev/null); then
        log_warning "Date formatting failed, using epoch timestamp"
        DATE_STR="$(date +%s 2>/dev/null || echo 'nodate')"
    fi
fi

FILENAME="speccy-${DATE_STR}.md"
LOG_FILE="speccy-${DATE_STR}.log"

# Determine output path
if [ "$ANDROID_ENV" = true ] && [ -d "/sdcard/Download" ]; then
    OUT="/sdcard/Download/$FILENAME"
    LOG_OUT="/sdcard/Download/$LOG_FILE"
    log_info "Output: Android Downloads directory"
elif [ -d "$HOME/Downloads" ]; then
    OUT="$HOME/Downloads/$FILENAME"
    LOG_OUT="$HOME/Downloads/$LOG_FILE"
    log_info "Output: User Downloads directory"
else
    OUT="./$FILENAME"
    LOG_OUT="./$LOG_FILE"
    log_info "Output: Current directory"
fi

log_info "File: $OUT"

# Check permissions and create directory if needed
check_permissions

echo ""

# ---------- INITIALIZE OUTPUT FILE ----------
log_info "Initializing output file..."

if ! append_safe "# Android Device Specification Report" "$OUT" "Header"; then
    handle_error 3 "Cannot write to output file: $OUT" "Check write permissions and disk space"
fi

append_safe "" "$OUT" "Header"
append_safe "**Generated:** $(date 2>/dev/null || echo 'Date unavailable')" "$OUT" "Header"
append_safe "**Export Tool:** KRYPTON v3" "$OUT" "Header"
append_safe "" "$OUT" "Header"

log_success "Output file initialized"

# ---------- BASIC DEVICE IDENTITIES ----------
log_info "Collecting device information..."

append_safe "## 📱 Device Information" "$OUT" "Device Info"
append_safe "" "$OUT" "Device Info"
append_safe "| Property | Value |" "$OUT" "Device Info"
append_safe "|----------|-------|" "$OUT" "Device Info"

# Collect device properties with error handling
if command -v getprop >/dev/null 2>&1; then
    append_safe "| Model | $(getprop ro.product.model 2>/dev/null || echo 'N/A') |" "$OUT" "Device Info"
    append_safe "| Device | $(getprop ro.product.device 2>/dev/null || echo 'N/A') |" "$OUT" "Device Info"
    append_safe "| Brand | $(getprop ro.product.brand 2>/dev/null || echo 'N/A') |" "$OUT" "Device Info"
    append_safe "| Manufacturer | $(getprop ro.product.manufacturer 2>/dev/null || echo 'N/A') |" "$OUT" "Device Info"
    append_safe "| Fingerprint | $(getprop ro.build.fingerprint 2>/dev/null || echo 'N/A') |" "$OUT" "Device Info"
    append_safe "| Build ID | $(getprop ro.build.id 2>/dev/null || echo 'N/A') |" "$OUT" "Device Info"
    append_safe "| Android Version | $(getprop ro.build.version.release 2>/dev/null || echo 'N/A') |" "$OUT" "Device Info"
    append_safe "| Security Patch | $(getprop ro.build.version.security_patch 2>/dev/null || echo 'N/A') |" "$OUT" "Device Info"
    append_safe "| ROM Type | $(getprop ro.boot.verifiedbootstate 2>/dev/null || echo 'N/A') |" "$OUT" "Device Info"
    log_success "Device information collected"
else
    append_safe "| Error | getprop command not available |" "$OUT" "Device Info"
    log_warning "getprop not available - device info limited"
fi

append_safe "" "$OUT" "Device Info"

# ---------- KERNEL + ROOT STATE ----------
echo "## 🔧 Kernel Information" >> "$OUT"
echo "" >> "$OUT"
echo "\`\`\`" >> "$OUT"
uname -a >> "$OUT"
echo "\`\`\`" >> "$OUT"
echo "" >> "$OUT"

echo "## 🔐 Root Environment" >> "$OUT"
echo "" >> "$OUT"
echo "**su binary:** $(which su 2>/dev/null || echo 'Not found')" >> "$OUT"
echo "" >> "$OUT"
echo "\`\`\`" >> "$OUT"
su -v 2>/dev/null >> "$OUT"
echo "\`\`\`" >> "$OUT"
echo "" >> "$OUT"

echo "## ⚙️ KernelSU Status" >> "$OUT"
echo "" >> "$OUT"
if [ -f "/sys/fs/ksu/version" ]; then
  echo "**Version:** $(cat /sys/fs/ksu/version 2>/dev/null)" >> "$OUT"
  echo "**Enabled:** $(cat /sys/fs/ksu/ksu_enabled 2>/dev/null)" >> "$OUT"
else
  echo "KernelSU not detected" >> "$OUT"
fi
echo "" >> "$OUT"

# ---------- BOOT / VB META / VERIFIED STATE ----------
echo "## 🔒 Verified Boot State" >> "$OUT"
echo "" >> "$OUT"
echo "**Boot State:** $(getprop ro.boot.verifiedbootstate)" >> "$OUT"
echo "" >> "$OUT"
echo "### VBMeta Information" >> "$OUT"
echo "" >> "$OUT"
echo "\`\`\`" >> "$OUT"
echo "Algorithm:" >> "$OUT"
cat /sys/firmware/devicetree/base/vbmeta/0/algorithm 2>/dev/null >> "$OUT"
echo "Digest:" >> "$OUT"
cat /sys/firmware/devicetree/base/vbmeta/0/digest 2>/dev/null >> "$OUT"
echo "\`\`\`" >> "$OUT"
echo "" >> "$OUT"

# ---------- HARDWARE INFORMATION ----------
echo "## 💻 CPU Information" >> "$OUT"
echo "" >> "$OUT"
echo "<details>" >> "$OUT"
echo "<summary>Click to expand CPU details</summary>" >> "$OUT"
echo "" >> "$OUT"
echo "\`\`\`" >> "$OUT"
cat /proc/cpuinfo >> "$OUT"
echo "\`\`\`" >> "$OUT"
echo "" >> "$OUT"
echo "</details>" >> "$OUT"
echo "" >> "$OUT"

echo "## 🧠 Memory Information" >> "$OUT"
echo "" >> "$OUT"
echo "<details>" >> "$OUT"
echo "<summary>Click to expand memory details</summary>" >> "$OUT"
echo "" >> "$OUT"
echo "\`\`\`" >> "$OUT"
cat /proc/meminfo >> "$OUT"
echo "\`\`\`" >> "$OUT"
echo "" >> "$OUT"
echo "</details>" >> "$OUT"
echo "" >> "$OUT"

# ---------- STORAGE + PARTITIONS ----------
echo "## 💾 Storage Information" >> "$OUT"
echo "" >> "$OUT"
echo "### Disk Usage" >> "$OUT"
echo "\`\`\`" >> "$OUT"
df -h >> "$OUT"
echo "\`\`\`" >> "$OUT"
echo "" >> "$OUT"

echo "### Partition Table" >> "$OUT"
echo "\`\`\`" >> "$OUT"
lsblk 2>/dev/null >> "$OUT"
echo "\`\`\`" >> "$OUT"
echo "" >> "$OUT"

echo "<details>" >> "$OUT"
echo "<summary>Mount Points (/proc/mounts)</summary>" >> "$OUT"
echo "" >> "$OUT"
echo "\`\`\`" >> "$OUT"
cat /proc/mounts >> "$OUT"
echo "\`\`\`" >> "$OUT"
echo "" >> "$OUT"
echo "</details>" >> "$OUT"
echo "" >> "$OUT"

echo "<details>" >> "$OUT"
echo "<summary>FSTAB Files</summary>" >> "$OUT"
echo "" >> "$OUT"
echo "\`\`\`" >> "$OUT"
cat /vendor/etc/fstab* 2>/dev/null >> "$OUT"
cat /system/etc/fstab* 2>/dev/null >> "$OUT"
echo "\`\`\`" >> "$OUT"
echo "" >> "$OUT"
echo "</details>" >> "$OUT"
echo "" >> "$OUT"

# ---------- HARDWARE SERVICES ----------
echo "## 📺 Display & Graphics" >> "$OUT"
echo "" >> "$OUT"
echo "<details>" >> "$OUT"
echo "<summary>Display Service</summary>" >> "$OUT"
echo "" >> "$OUT"
echo "\`\`\`" >> "$OUT"
dumpsys display >> "$OUT"
echo "\`\`\`" >> "$OUT"
echo "" >> "$OUT"
echo "</details>" >> "$OUT"
echo "" >> "$OUT"

echo "<details>" >> "$OUT"
echo "<summary>SurfaceFlinger (First 120 lines)</summary>" >> "$OUT"
echo "" >> "$OUT"
echo "\`\`\`" >> "$OUT"
dumpsys SurfaceFlinger | head -n 120 >> "$OUT"
echo "\`\`\`" >> "$OUT"
echo "" >> "$OUT"
echo "</details>" >> "$OUT"
echo "" >> "$OUT"

# ---------- POWER MANAGEMENT ----------
echo "## 🔋 Power & Battery" >> "$OUT"
echo "" >> "$OUT"
echo "### Battery Status" >> "$OUT"
echo "\`\`\`" >> "$OUT"
dumpsys battery >> "$OUT"
echo "\`\`\`" >> "$OUT"
echo "" >> "$OUT"

echo "<details>" >> "$OUT"
echo "<summary>Power Management</summary>" >> "$OUT"
echo "" >> "$OUT"
echo "\`\`\`" >> "$OUT"
dumpsys power >> "$OUT"
echo "\`\`\`" >> "$OUT"
echo "" >> "$OUT"
echo "</details>" >> "$OUT"
echo "" >> "$OUT"

# ---------- CONNECTIVITY ----------
echo "## 📡 Connectivity" >> "$OUT"
echo "" >> "$OUT"
echo "<details>" >> "$OUT"
echo "<summary>WiFi Service</summary>" >> "$OUT"
echo "" >> "$OUT"
echo "\`\`\`" >> "$OUT"
dumpsys wifi >> "$OUT"
echo "\`\`\`" >> "$OUT"
echo "" >> "$OUT"
echo "</details>" >> "$OUT"
echo "" >> "$OUT"

echo "<details>" >> "$OUT"
echo "<summary>Telephony Registry</summary>" >> "$OUT"
echo "" >> "$OUT"
echo "\`\`\`" >> "$OUT"
dumpsys telephony.registry >> "$OUT"
echo "\`\`\`" >> "$OUT"
echo "" >> "$OUT"
echo "</details>" >> "$OUT"
echo "" >> "$OUT"

echo "<details>" >> "$OUT"
echo "<summary>Radio/Phone Service</summary>" >> "$OUT"
echo "" >> "$OUT"
echo "\`\`\`" >> "$OUT"
dumpsys phone >> "$OUT"
echo "\`\`\`" >> "$OUT"
echo "" >> "$OUT"
echo "</details>" >> "$OUT"
echo "" >> "$OUT"

# ---------- SENSORS ----------
echo "## 📊 Sensors" >> "$OUT"
echo "" >> "$OUT"
echo "<details>" >> "$OUT"
echo "<summary>Sensor Service</summary>" >> "$OUT"
echo "" >> "$OUT"
echo "\`\`\`" >> "$OUT"
dumpsys sensorservice >> "$OUT"
echo "\`\`\`" >> "$OUT"
echo "" >> "$OUT"
echo "</details>" >> "$OUT"
echo "" >> "$OUT"

# ---------- SOFTWARE ----------
echo "## 📦 Software" >> "$OUT"
echo "" >> "$OUT"
echo "<details>" >> "$OUT"
echo "<summary>Installed Packages</summary>" >> "$OUT"
echo "" >> "$OUT"
echo "\`\`\`" >> "$OUT"
pm list packages >> "$OUT"
echo "\`\`\`" >> "$OUT"
echo "" >> "$OUT"
echo "</details>" >> "$OUT"
echo "" >> "$OUT"

echo "<details>" >> "$OUT"
echo "<summary>Activity Manager (Top 150 lines)</summary>" >> "$OUT"
echo "" >> "$OUT"
echo "\`\`\`" >> "$OUT"
dumpsys activity activities | head -n 150 >> "$OUT"
echo "\`\`\`" >> "$OUT"
echo "" >> "$OUT"
echo "</details>" >> "$OUT"
echo "" >> "$OUT"

# ---------- FINAL OUTPUT ----------
append_safe "---" "$OUT" "Footer"
append_safe "" "$OUT" "Footer"
append_safe "**Report generated by speccy.sh**" "$OUT" "Footer"
append_safe "**Export completed:** $(date 2>/dev/null || echo 'Date unavailable')" "$OUT" "Footer"

log_success "Spec exported to: $OUT"

# Verify file was created and has content
if [ ! -f "$OUT" ]; then
    handle_error 3 "Output file was not created: $OUT" "Check write permissions and disk space"
fi

file_size=$(wc -c < "$OUT" 2>/dev/null || echo "0")
if [ "$file_size" -lt 100 ]; then
    handle_error 3 "Output file appears to be empty or corrupted" "Check if all commands executed properly"
fi

log_info "File size: $file_size bytes"
log_info "Displaying content in terminal:"
echo ""

# Safe file display with error handling
if ! cat "$OUT" 2>/dev/null; then
    log_error "Failed to display file content"
    log_info "File location: $OUT"
    exit 3
fi

log_success "Export completed successfully!"
