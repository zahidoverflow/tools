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
#     - ROM debugging and analysis
#     - Kernel analysis and root detection research
#     - Device integrity and boot state verification
#     - Hardware compatibility verification
#     - Security research and false-positive analysis
#     - Reproducible bug reporting with full device context
#
#  COMPATIBILITY:
#  --------------
#  Works with any rooted Android device including:
#     - Magisk rooted devices
#     - KernelSU rooted devices  
#     - SuperSU rooted devices
#     - Custom ROM devices with built-in root
#     - AOSP builds with root access
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
log_info "Collecting kernel and root information..."

append_safe "## 🔧 Kernel Information" "$OUT" "Kernel Info"
append_safe "" "$OUT" "Kernel Info"
append_safe "\`\`\`" "$OUT" "Kernel Info"
if ! uname -a >> "$OUT" 2>/dev/null; then
    append_safe "Kernel information unavailable" "$OUT" "Kernel Info"
    log_warning "Failed to get kernel information"
fi
append_safe "\`\`\`" "$OUT" "Kernel Info"
append_safe "" "$OUT" "Kernel Info"

append_safe "## 🔐 Root Environment" "$OUT" "Root Info"
append_safe "" "$OUT" "Root Info"

# Check for su binary
SU_BINARY=$(which su 2>/dev/null || echo 'Not found')
append_safe "**su binary:** $SU_BINARY" "$OUT" "Root Info"
append_safe "" "$OUT" "Root Info"

# Get su version if available
if [ "$SU_BINARY" != "Not found" ]; then
    append_safe "\`\`\`" "$OUT" "Root Info"
    if ! su -v >> "$OUT" 2>/dev/null; then
        append_safe "su version information unavailable" "$OUT" "Root Info"
        SU_VERSION_OUTPUT=""
    else
        SU_VERSION_OUTPUT=$(su -v 2>/dev/null || echo '')
    fi
    append_safe "\`\`\`" "$OUT" "Root Info"
else
    append_safe "**Status:** No root access detected" "$OUT" "Root Info"
    SU_VERSION_OUTPUT=""
fi
append_safe "" "$OUT" "Root Info"

# Enhanced root management detection
append_safe "## ⚙️ Root Management" "$OUT" "Root Mgmt Info"
append_safe "" "$OUT" "Root Mgmt Info"

# Detect various root management solutions
ROOT_METHOD="Unknown"
ROOT_DETAILS=""

# Check for Magisk
if [ -f "/data/adb/magisk/magisk" ] || [ -f "/sbin/magisk" ] || [ -d "/data/adb/magisk" ]; then
    ROOT_METHOD="Magisk"
    if [ -f "/data/adb/magisk/magisk" ]; then
        MAGISK_VERSION=$(/data/adb/magisk/magisk -V 2>/dev/null || echo 'Unknown')
        ROOT_DETAILS="Version: $MAGISK_VERSION"
    fi
    append_safe "**Method:** $ROOT_METHOD" "$OUT" "Root Mgmt Info"
    append_safe "**Details:** $ROOT_DETAILS" "$OUT" "Root Mgmt Info"
    if [ -d "/data/adb/modules" ]; then
        MODULE_COUNT=$(ls -1 /data/adb/modules 2>/dev/null | wc -l)
        append_safe "**Modules:** $MODULE_COUNT modules installed" "$OUT" "Root Mgmt Info"
    fi
# Check for KernelSU
elif [ -f "/sys/fs/ksu/version" ] || echo "$SU_VERSION_OUTPUT" | grep -q "KernelSU"; then
    ROOT_METHOD="KernelSU"
    if [ -f "/sys/fs/ksu/version" ]; then
        KSU_VERSION=$(cat /sys/fs/ksu/version 2>/dev/null || echo 'Unknown')
        ROOT_DETAILS="Version: $KSU_VERSION"
    else
        ROOT_DETAILS="Version: $SU_VERSION_OUTPUT"
    fi
    append_safe "**Method:** $ROOT_METHOD" "$OUT" "Root Mgmt Info"
    append_safe "**Details:** $ROOT_DETAILS" "$OUT" "Root Mgmt Info"
# Check for SuperSU
elif [ -f "/system/bin/daemonsu" ] || [ -f "/system/xbin/daemonsu" ] || echo "$SU_VERSION_OUTPUT" | grep -q "SUPERSU"; then
    ROOT_METHOD="SuperSU"
    ROOT_DETAILS="Legacy SuperSU installation detected"
    append_safe "**Method:** $ROOT_METHOD" "$OUT" "Root Mgmt Info"
    append_safe "**Details:** $ROOT_DETAILS" "$OUT" "Root Mgmt Info"
# Check for other su implementations
elif [ "$SU_BINARY" != "Not found" ]; then
    ROOT_METHOD="Custom/Other"
    ROOT_DETAILS="su binary: $SU_BINARY"
    if [ -n "$SU_VERSION_OUTPUT" ]; then
        ROOT_DETAILS="$ROOT_DETAILS, Version: $SU_VERSION_OUTPUT"
    fi
    append_safe "**Method:** $ROOT_METHOD" "$OUT" "Root Mgmt Info"
    append_safe "**Details:** $ROOT_DETAILS" "$OUT" "Root Mgmt Info"
else
    append_safe "**Method:** No root management detected" "$OUT" "Root Mgmt Info"
    append_safe "**Note:** Script may still work with built-in root access" "$OUT" "Root Mgmt Info"
fi

# Check for additional root indicators
if [ -f "/system/app/Superuser.apk" ] || [ -f "/system/app/SuperSU.apk" ]; then
    append_safe "**Legacy apps:** Superuser/SuperSU APK detected" "$OUT" "Root Mgmt Info"
fi

if [ -f "/system/etc/init.d/99SuperSUDaemon" ]; then
    append_safe "**Init scripts:** SuperSU daemon script detected" "$OUT" "Root Mgmt Info"
fi

append_safe "" "$OUT" "Root Mgmt Info"

# ---------- BOOT / VB META / VERIFIED STATE ----------
log_info "Collecting verified boot state..."

append_safe "## 🔒 Verified Boot State" "$OUT" "VB Info"
append_safe "" "$OUT" "VB Info"

# Get boot state
BOOT_STATE=$(getprop ro.boot.verifiedbootstate 2>/dev/null || echo 'N/A')
append_safe "**Boot State:** $BOOT_STATE" "$OUT" "VB Info"

# Additional boot-related properties
BOOT_MODE=$(getprop ro.bootmode 2>/dev/null || echo 'N/A')
append_safe "**Boot Mode:** $BOOT_MODE" "$OUT" "VB Info"

VBMETA_STATE=$(getprop ro.boot.vbmeta.device_state 2>/dev/null || echo 'N/A')
append_safe "**VBMeta Device State:** $VBMETA_STATE" "$OUT" "VB Info"

append_safe "" "$OUT" "VB Info"
append_safe "### VBMeta Information" "$OUT" "VB Info"
append_safe "" "$OUT" "VB Info"
append_safe "\`\`\`" "$OUT" "VB Info"

# Try multiple VBMeta paths and methods
VBMETA_FOUND=false

if [ -f "/sys/firmware/devicetree/base/vbmeta/0/algorithm" ]; then
    append_safe "Algorithm (path 0):" "$OUT" "VB Info"
    if cat /sys/firmware/devicetree/base/vbmeta/0/algorithm >> "$OUT" 2>/dev/null; then
        VBMETA_FOUND=true
    else
        append_safe "Unable to read algorithm" "$OUT" "VB Info"
    fi
fi

if [ -f "/sys/firmware/devicetree/base/vbmeta/0/digest" ]; then
    append_safe "Digest (path 0):" "$OUT" "VB Info"
    if cat /sys/firmware/devicetree/base/vbmeta/0/digest >> "$OUT" 2>/dev/null; then
        VBMETA_FOUND=true
    else
        append_safe "Unable to read digest" "$OUT" "VB Info"
    fi
fi

# Try alternative paths
for i in 1 2 3; do
    if [ -f "/sys/firmware/devicetree/base/vbmeta/$i/algorithm" ]; then
        append_safe "Algorithm (path $i):" "$OUT" "VB Info"
        cat /sys/firmware/devicetree/base/vbmeta/$i/algorithm >> "$OUT" 2>/dev/null
        VBMETA_FOUND=true
    fi
done

if [ "$VBMETA_FOUND" = false ]; then
    append_safe "VBMeta information not accessible via devicetree" "$OUT" "VB Info"
    append_safe "This is normal on some devices/ROMs" "$OUT" "VB Info"
fi

append_safe "\`\`\`" "$OUT" "VB Info"
append_safe "" "$OUT" "VB Info"

# ---------- BOOT / VB META / VERIFIED STATE ----------
log_info "Collecting verified boot state..."

append_safe "## 🔒 Verified Boot State" "$OUT" "VB Info"
append_safe "" "$OUT" "VB Info"

# Get boot state
BOOT_STATE=$(getprop ro.boot.verifiedbootstate 2>/dev/null || echo 'N/A')
append_safe "**Boot State:** $BOOT_STATE" "$OUT" "VB Info"

# Additional boot-related properties
BOOT_MODE=$(getprop ro.bootmode 2>/dev/null || echo 'N/A')
append_safe "**Boot Mode:** $BOOT_MODE" "$OUT" "VB Info"

VBMETA_STATE=$(getprop ro.boot.vbmeta.device_state 2>/dev/null || echo 'N/A')
append_safe "**VBMeta Device State:** $VBMETA_STATE" "$OUT" "VB Info"

append_safe "" "$OUT" "VB Info"
append_safe "### VBMeta Information" "$OUT" "VB Info"
append_safe "" "$OUT" "VB Info"
append_safe "\`\`\`" "$OUT" "VB Info"

# Try multiple VBMeta paths and methods
VBMETA_FOUND=false

if [ -f "/sys/firmware/devicetree/base/vbmeta/0/algorithm" ]; then
    append_safe "Algorithm (path 0):" "$OUT" "VB Info"
    if cat /sys/firmware/devicetree/base/vbmeta/0/algorithm >> "$OUT" 2>/dev/null; then
        VBMETA_FOUND=true
    else
        append_safe "Unable to read algorithm" "$OUT" "VB Info"
    fi
fi

if [ -f "/sys/firmware/devicetree/base/vbmeta/0/digest" ]; then
    append_safe "Digest (path 0):" "$OUT" "VB Info"
    if cat /sys/firmware/devicetree/base/vbmeta/0/digest >> "$OUT" 2>/dev/null; then
        VBMETA_FOUND=true
    else
        append_safe "Unable to read digest" "$OUT" "VB Info"
    fi
fi

# Try alternative paths
for i in 1 2 3; do
    if [ -f "/sys/firmware/devicetree/base/vbmeta/$i/algorithm" ]; then
        append_safe "Algorithm (path $i):" "$OUT" "VB Info"
        cat /sys/firmware/devicetree/base/vbmeta/$i/algorithm >> "$OUT" 2>/dev/null
        VBMETA_FOUND=true
    fi
done

if [ "$VBMETA_FOUND" = false ]; then
    append_safe "VBMeta information not accessible via devicetree" "$OUT" "VB Info"
    append_safe "This is normal on some devices/ROMs" "$OUT" "VB Info"
fi

append_safe "\`\`\`" "$OUT" "VB Info"
append_safe "" "$OUT" "VB Info"

log_success "Verified boot information collected"

# ---------- HARDWARE INFORMATION ----------
log_info "Collecting hardware information..."

append_safe "## 💻 CPU Information" "$OUT" "CPU Info"
append_safe "" "$OUT" "CPU Info"
append_safe "<details>" "$OUT" "CPU Info"
append_safe "<summary>Click to expand CPU details</summary>" "$OUT" "CPU Info"
append_safe "" "$OUT" "CPU Info"
append_safe "\`\`\`" "$OUT" "CPU Info"
if ! cat /proc/cpuinfo >> "$OUT" 2>/dev/null; then
    append_safe "CPU information unavailable" "$OUT" "CPU Info"
fi
append_safe "\`\`\`" "$OUT" "CPU Info"
append_safe "" "$OUT" "CPU Info"
append_safe "</details>" "$OUT" "CPU Info"
append_safe "" "$OUT" "CPU Info"

append_safe "## 🧠 Memory Information" "$OUT" "Memory Info"
append_safe "" "$OUT" "Memory Info"
append_safe "<details>" "$OUT" "Memory Info"
append_safe "<summary>Click to expand memory details</summary>" "$OUT" "Memory Info"
append_safe "" "$OUT" "Memory Info"
append_safe "\`\`\`" "$OUT" "Memory Info"
if ! cat /proc/meminfo >> "$OUT" 2>/dev/null; then
    append_safe "Memory information unavailable" "$OUT" "Memory Info"
fi
append_safe "\`\`\`" "$OUT" "Memory Info"
append_safe "" "$OUT" "Memory Info"
append_safe "</details>" "$OUT" "Memory Info"
append_safe "" "$OUT" "Memory Info"

# ---------- STORAGE + PARTITIONS ----------
log_info "Collecting storage and partition information..."

append_safe "## 💾 Storage Information" "$OUT" "Storage Info"
append_safe "" "$OUT" "Storage Info"
append_safe "### Disk Usage" "$OUT" "Storage Info"
append_safe "\`\`\`" "$OUT" "Storage Info"
if ! df -h >> "$OUT" 2>/dev/null; then
    append_safe "Disk usage information unavailable" "$OUT" "Storage Info"
    log_warning "Failed to get disk usage information"
fi
append_safe "\`\`\`" "$OUT" "Storage Info"
append_safe "" "$OUT" "Storage Info"

append_safe "### Partition Table" "$OUT" "Storage Info"
append_safe "\`\`\`" "$OUT" "Storage Info"

# Try multiple methods for partition information
PART_INFO_FOUND=false

# Try lsblk first
if command -v lsblk >/dev/null 2>&1; then
    if lsblk >> "$OUT" 2>/dev/null && [ $? -eq 0 ]; then
        PART_INFO_FOUND=true
    fi
fi

# Fallback to /proc/partitions if lsblk failed
if [ "$PART_INFO_FOUND" = false ] && [ -f "/proc/partitions" ]; then
    append_safe "=== /proc/partitions ===" "$OUT" "Storage Info"
    if cat /proc/partitions >> "$OUT" 2>/dev/null; then
        PART_INFO_FOUND=true
    fi
fi

# Try fdisk as another fallback
if [ "$PART_INFO_FOUND" = false ] && command -v fdisk >/dev/null 2>&1; then
    append_safe "=== Available block devices ===" "$OUT" "Storage Info"
    if fdisk -l >> "$OUT" 2>/dev/null; then
        PART_INFO_FOUND=true
    fi
fi

if [ "$PART_INFO_FOUND" = false ]; then
    append_safe "Partition information unavailable" "$OUT" "Storage Info"
    append_safe "This may be due to permissions or missing tools" "$OUT" "Storage Info"
fi

append_safe "\`\`\`" "$OUT" "Storage Info"
append_safe "" "$OUT" "Storage Info"

append_safe "<details>" "$OUT" "Storage Info"
append_safe "<summary>Mount Points (/proc/mounts)</summary>" "$OUT" "Storage Info"
append_safe "" "$OUT" "Storage Info"
append_safe "\`\`\`" "$OUT" "Storage Info"
if ! cat /proc/mounts >> "$OUT" 2>/dev/null; then
    append_safe "Mount information unavailable" "$OUT" "Storage Info"
    log_warning "Failed to read /proc/mounts"
fi
append_safe "\`\`\`" "$OUT" "Storage Info"
append_safe "" "$OUT" "Storage Info"
append_safe "</details>" "$OUT" "Storage Info"
append_safe "" "$OUT" "Storage Info"

append_safe "<details>" "$OUT" "Storage Info"
append_safe "<summary>FSTAB Files</summary>" "$OUT" "Storage Info"
append_safe "" "$OUT" "Storage Info"
append_safe "\`\`\`" "$OUT" "Storage Info"

FSTAB_FOUND=false

# Check multiple FSTAB locations
for fstab_path in "/vendor/etc/fstab*" "/system/etc/fstab*" "/etc/fstab*"; do
    if ls $fstab_path >/dev/null 2>&1; then
        append_safe "=== $fstab_path ===" "$OUT" "Storage Info"
        if cat $fstab_path >> "$OUT" 2>/dev/null; then
            FSTAB_FOUND=true
        fi
    fi
done

if [ "$FSTAB_FOUND" = false ]; then
    append_safe "No accessible FSTAB files found" "$OUT" "Storage Info"
fi

append_safe "\`\`\`" "$OUT" "Storage Info"
append_safe "" "$OUT" "Storage Info"
append_safe "</details>" "$OUT" "Storage Info"
append_safe "" "$OUT" "Storage Info"

# ---------- HARDWARE SERVICES ----------
log_info "Collecting hardware service information..."

append_safe "## 📺 Display & Graphics" "$OUT" "Display Info"
append_safe "" "$OUT" "Display Info"
append_safe "<details>" "$OUT" "Display Info"
append_safe "<summary>Display Service</summary>" "$OUT" "Display Info"
append_safe "" "$OUT" "Display Info"
append_safe "\`\`\`" "$OUT" "Display Info"
if command -v dumpsys >/dev/null 2>&1; then
    if ! dumpsys display >> "$OUT" 2>/dev/null; then
        append_safe "Display service information unavailable" "$OUT" "Display Info"
    fi
else
    append_safe "dumpsys command not available" "$OUT" "Display Info"
fi
append_safe "\`\`\`" "$OUT" "Display Info"
append_safe "" "$OUT" "Display Info"
append_safe "</details>" "$OUT" "Display Info"
append_safe "" "$OUT" "Display Info"

append_safe "<details>" "$OUT" "Display Info"
append_safe "<summary>SurfaceFlinger (First 120 lines)</summary>" "$OUT" "Display Info"
append_safe "" "$OUT" "Display Info"
append_safe "\`\`\`" "$OUT" "Display Info"
if command -v dumpsys >/dev/null 2>&1; then
    if ! dumpsys SurfaceFlinger | head -n 120 >> "$OUT" 2>/dev/null; then
        append_safe "SurfaceFlinger information unavailable" "$OUT" "Display Info"
    fi
else
    append_safe "dumpsys command not available" "$OUT" "Display Info"
fi
append_safe "\`\`\`" "$OUT" "Display Info"
append_safe "" "$OUT" "Display Info"
append_safe "</details>" "$OUT" "Display Info"
append_safe "" "$OUT" "Display Info"

# ---------- POWER MANAGEMENT ----------
log_info "Collecting power management information..."

append_safe "## 🔋 Power & Battery" "$OUT" "Power Info"
append_safe "" "$OUT" "Power Info"
append_safe "### Battery Status" "$OUT" "Power Info"
append_safe "\`\`\`" "$OUT" "Power Info"
if command -v dumpsys >/dev/null 2>&1; then
    if ! dumpsys battery >> "$OUT" 2>/dev/null; then
        append_safe "Battery information unavailable" "$OUT" "Power Info"
    fi
else
    append_safe "dumpsys command not available" "$OUT" "Power Info"
fi
append_safe "\`\`\`" "$OUT" "Power Info"
append_safe "" "$OUT" "Power Info"

append_safe "<details>" "$OUT" "Power Info"
append_safe "<summary>Power Management</summary>" "$OUT" "Power Info"
append_safe "" "$OUT" "Power Info"
append_safe "\`\`\`" "$OUT" "Power Info"
if command -v dumpsys >/dev/null 2>&1; then
    if ! dumpsys power >> "$OUT" 2>/dev/null; then
        append_safe "Power management information unavailable" "$OUT" "Power Info"
    fi
else
    append_safe "dumpsys command not available" "$OUT" "Power Info"
fi
append_safe "\`\`\`" "$OUT" "Power Info"
append_safe "" "$OUT" "Power Info"
append_safe "</details>" "$OUT" "Power Info"
append_safe "" "$OUT" "Power Info"

# ---------- CONNECTIVITY ----------
log_info "Collecting connectivity information..."

append_safe "## 📡 Connectivity" "$OUT" "Connectivity Info"
append_safe "" "$OUT" "Connectivity Info"
append_safe "<details>" "$OUT" "Connectivity Info"
append_safe "<summary>WiFi Service</summary>" "$OUT" "Connectivity Info"
append_safe "" "$OUT" "Connectivity Info"
append_safe "\`\`\`" "$OUT" "Connectivity Info"
if command -v dumpsys >/dev/null 2>&1; then
    if ! dumpsys wifi >> "$OUT" 2>/dev/null; then
        append_safe "WiFi service information unavailable" "$OUT" "Connectivity Info"
    fi
else
    append_safe "dumpsys command not available" "$OUT" "Connectivity Info"
fi
append_safe "\`\`\`" "$OUT" "Connectivity Info"
append_safe "" "$OUT" "Connectivity Info"
append_safe "</details>" "$OUT" "Connectivity Info"
append_safe "" "$OUT" "Connectivity Info"

append_safe "<details>" "$OUT" "Connectivity Info"
append_safe "<summary>Telephony Registry</summary>" "$OUT" "Connectivity Info"
append_safe "" "$OUT" "Connectivity Info"
append_safe "\`\`\`" "$OUT" "Connectivity Info"
if command -v dumpsys >/dev/null 2>&1; then
    if ! dumpsys telephony.registry >> "$OUT" 2>/dev/null; then
        append_safe "Telephony registry information unavailable" "$OUT" "Connectivity Info"
    fi
else
    append_safe "dumpsys command not available" "$OUT" "Connectivity Info"
fi
append_safe "\`\`\`" "$OUT" "Connectivity Info"
append_safe "" "$OUT" "Connectivity Info"
append_safe "</details>" "$OUT" "Connectivity Info"
append_safe "" "$OUT" "Connectivity Info"

append_safe "<details>" "$OUT" "Connectivity Info"
append_safe "<summary>Radio/Phone Service</summary>" "$OUT" "Connectivity Info"
append_safe "" "$OUT" "Connectivity Info"
append_safe "\`\`\`" "$OUT" "Connectivity Info"
if command -v dumpsys >/dev/null 2>&1; then
    if ! dumpsys phone >> "$OUT" 2>/dev/null; then
        append_safe "Phone service information unavailable" "$OUT" "Connectivity Info"
    fi
else
    append_safe "dumpsys command not available" "$OUT" "Connectivity Info"
fi
append_safe "\`\`\`" "$OUT" "Connectivity Info"
append_safe "" "$OUT" "Connectivity Info"
append_safe "</details>" "$OUT" "Connectivity Info"
append_safe "" "$OUT" "Connectivity Info"

# ---------- SENSORS ----------
log_info "Collecting sensor information..."

append_safe "## 📊 Sensors" "$OUT" "Sensor Info"
append_safe "" "$OUT" "Sensor Info"
append_safe "<details>" "$OUT" "Sensor Info"
append_safe "<summary>Sensor Service</summary>" "$OUT" "Sensor Info"
append_safe "" "$OUT" "Sensor Info"
append_safe "\`\`\`" "$OUT" "Sensor Info"
if command -v dumpsys >/dev/null 2>&1; then
    if ! dumpsys sensorservice >> "$OUT" 2>/dev/null; then
        append_safe "Sensor service information unavailable" "$OUT" "Sensor Info"
    fi
else
    append_safe "dumpsys command not available" "$OUT" "Sensor Info"
fi
append_safe "\`\`\`" "$OUT" "Sensor Info"
append_safe "" "$OUT" "Sensor Info"
append_safe "</details>" "$OUT" "Sensor Info"
append_safe "" "$OUT" "Sensor Info"

# ---------- SOFTWARE ----------
log_info "Collecting software information..."

append_safe "## 📦 Software" "$OUT" "Software Info"
append_safe "" "$OUT" "Software Info"
append_safe "<details>" "$OUT" "Software Info"
append_safe "<summary>Installed Packages</summary>" "$OUT" "Software Info"
append_safe "" "$OUT" "Software Info"
append_safe "\`\`\`" "$OUT" "Software Info"
if command -v pm >/dev/null 2>&1; then
    if ! pm list packages >> "$OUT" 2>/dev/null; then
        append_safe "Package list unavailable" "$OUT" "Software Info"
    fi
else
    append_safe "pm command not available" "$OUT" "Software Info"
fi
append_safe "\`\`\`" "$OUT" "Software Info"
append_safe "" "$OUT" "Software Info"
append_safe "</details>" "$OUT" "Software Info"
append_safe "" "$OUT" "Software Info"

append_safe "<details>" "$OUT" "Software Info"
append_safe "<summary>Activity Manager (Top 150 lines)</summary>" "$OUT" "Software Info"
append_safe "" "$OUT" "Software Info"
append_safe "\`\`\`" "$OUT" "Software Info"
if command -v dumpsys >/dev/null 2>&1; then
    if ! dumpsys activity activities | head -n 150 >> "$OUT" 2>/dev/null; then
        append_safe "Activity manager information unavailable" "$OUT" "Software Info"
    fi
else
    append_safe "dumpsys command not available" "$OUT" "Software Info"
fi
append_safe "\`\`\`" "$OUT" "Software Info"
append_safe "" "$OUT" "Software Info"
append_safe "</details>" "$OUT" "Software Info"
append_safe "" "$OUT" "Software Info"

# ---------- FINAL OUTPUT ----------
append_safe "---" "$OUT" "Footer"
append_safe "" "$OUT" "Footer"
append_safe "**Report generated by speccy.sh**" "$OUT" "Footer"
append_safe "**Export completed:** $(date 2>/dev/null || echo 'Date unavailable')" "$OUT" "Footer"

echo ""
echo "════════════════════════════════════════════════════════"
echo "🎉 SPECCY EXPORT COMPLETED SUCCESSFULLY"
echo "════════════════════════════════════════════════════════"

# Verify file was created and has content
if [ ! -f "$OUT" ]; then
    handle_error 3 "Output file was not created: $OUT" "Check write permissions and disk space"
fi

file_size=$(wc -c < "$OUT" 2>/dev/null || echo "0")
if [ "$file_size" -lt 100 ]; then
    handle_error 3 "Output file appears to be empty or corrupted" "Check if all commands executed properly"
fi

echo "📄 Report File: $OUT"
echo "📊 File Size: $file_size bytes"
echo "📅 Timestamp: $(date 2>/dev/null || echo 'Date unavailable')"
echo ""
echo "🔍 REPORT PREVIEW (First 50 lines):"
echo "────────────────────────────────────────────────────────"

# Show only a preview of the file, not the entire content
if ! head -n 50 "$OUT" 2>/dev/null; then
    log_error "Failed to display file preview"
    echo "File location: $OUT"
else
    echo ""
    echo "────────────────────────────────────────────────────────"
    echo "📖 Full report available at: $OUT"
    echo "💡 Use 'cat $OUT' to view complete content"
    echo "💡 Use 'less $OUT' for paginated viewing"
fi

echo ""
log_success "Export completed successfully!"
