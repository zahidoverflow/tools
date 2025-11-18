#!/system/bin/sh
# ============================================================
#  Speccy (v4)
#  Author: zahidoverflow
#
#  ONE-LINER INSTALLATION:
#  curl -fsSL https://zahidoverflow.github.io/tools/speccy.sh | sudo bash
#
#  UPDATE LOG:
#  -----------
#  v4.0 (Nov 2025):
#    • Refactored to organized multi-file output structure
#    • Removed emojis for professional appearance
#    • Creates dedicated Speccy folder with categorized files
#    • Enhanced terminal output with clean progress indicators
#    • Improved file organization and readability
#  
#  v3.0 (Nov 2025):
#    • Added dependency checks for Termux compatibility
#    • Implemented date-formatted output filenames
#    • Smart path detection and enhanced error handling
#    • Universal root detection for any rooted Android device
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
    echo "[INFO] $1"
}

log_success() {
    echo "[SUCCESS] $1"
}

log_warning() {
    echo "[WARNING] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
    # Log errors to file
    if [ -n "$LOG_OUT" ]; then
        echo "$(date 2>/dev/null || echo 'Date unavailable') [ERROR] $1" >> "$LOG_OUT" 2>/dev/null
    fi
}

log_critical() {
    echo "[CRITICAL] $1" >&2
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
    # Check if we can create and write to target directory
    if [ ! -d "$BASE_OUT" ]; then
        log_info "Creating output directory: $BASE_OUT"
        if ! mkdir -p "$BASE_OUT" 2>/dev/null; then
            handle_error 3 "Cannot create target directory: $BASE_OUT" "Try running with sudo or choose a different location"
        fi
        log_success "Created directory structure"
    fi
    
    if [ ! -w "$BASE_OUT" ]; then
        handle_error 2 "No write permission to: $BASE_OUT" "Try running with sudo or choose a writable location"
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
        if [ -d "$OUTPUT_DIR" ]; then
            log_info "Cleaning up incomplete analysis due to error..."
            rm -rf "$OUTPUT_DIR" 2>/dev/null
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
# Generate timestamp-formatted folder name (YYYYMMDDHHMM)
if ! DATE_STR=$(date '+%Y%m%d%H%M' 2>/dev/null); then
    log_warning "Standard date command failed, using fallback"
    if ! DATE_STR=$(date '+%Y%m%d%H%M' 2>/dev/null); then
        log_warning "Date formatting failed, using epoch timestamp"
        DATE_STR="$(date +%s 2>/dev/null || echo 'nodate')"
    fi
fi

FOLDER_NAME="Speccy-${DATE_STR}"
LOG_FILE="export.log"

# Determine base output path
if [ "$ANDROID_ENV" = true ] && [ -d "/sdcard/Download" ]; then
    BASE_OUT="/sdcard/Download/$FOLDER_NAME"
    log_info "Output location: Android Downloads directory"
elif [ -d "$HOME/Downloads" ]; then
    BASE_OUT="$HOME/Downloads/$FOLDER_NAME"
    log_info "Output location: User Downloads directory"
else
    BASE_OUT="./$FOLDER_NAME"
    log_info "Output location: Current directory"
fi

# Create organized file structure
DEVICE_FILE="$BASE_OUT/01-device-info.md"
KERNEL_FILE="$BASE_OUT/02-kernel-root.md"
BOOT_FILE="$BASE_OUT/03-boot-security.md"
ROOT_MODULES_FILE="$BASE_OUT/04-root-modules.md"
HARDWARE_FILE="$BASE_OUT/05-hardware.md"
STORAGE_FILE="$BASE_OUT/06-storage.md"
SERVICES_FILE="$BASE_OUT/07-services.md"
SOFTWARE_FILE="$BASE_OUT/08-software.md"
PLAY_INTEGRITY_FILE="$BASE_OUT/09-play-integrity.md"
SUMMARY_FILE="$BASE_OUT/00-SUMMARY.md"
LOG_OUT="$BASE_OUT/export.log"

log_info "Creating directory structure: $BASE_OUT"

# Check permissions and create directory if needed
check_permissions

echo ""

# ---------- INITIALIZE OUTPUT FILES ----------
log_info "Initializing output files..."

# Create summary file
if ! append_safe "# Android Device Analysis Summary" "$SUMMARY_FILE" "Summary"; then
    handle_error 3 "Cannot write to summary file: $SUMMARY_FILE" "Check write permissions and disk space"
fi
append_safe "" "$SUMMARY_FILE" "Summary"
append_safe "**Generated:** $(date 2>/dev/null || echo 'Date unavailable')" "$SUMMARY_FILE" "Summary"
append_safe "**Export Tool:** Speccy v4.1" "$SUMMARY_FILE" "Summary"
append_safe "**Analysis ID:** ${DATE_STR}" "$SUMMARY_FILE" "Summary"
append_safe "" "$SUMMARY_FILE" "Summary"
append_safe "## File Structure" "$SUMMARY_FILE" "Summary"
append_safe "" "$SUMMARY_FILE" "Summary"
append_safe "| File | Description |" "$SUMMARY_FILE" "Summary"
append_safe "|------|-------------|" "$SUMMARY_FILE" "Summary"
append_safe "| \`00-SUMMARY.md\` | Analysis overview and file index |" "$SUMMARY_FILE" "Summary"
append_safe "| \`01-device-info.md\` | Device specifications and build information |" "$SUMMARY_FILE" "Summary"
append_safe "| \`02-kernel-root.md\` | Kernel version and root management details |" "$SUMMARY_FILE" "Summary"
append_safe "| \`03-boot-security.md\` | Boot state and security verification |" "$SUMMARY_FILE" "Summary"
append_safe "| \`04-root-modules.md\` | Root modules, configurations, and settings |" "$SUMMARY_FILE" "Summary"
append_safe "| \`05-hardware.md\` | CPU, memory, and hardware configuration |" "$SUMMARY_FILE" "Summary"
append_safe "| \`06-storage.md\` | Storage, partitions, and file systems |" "$SUMMARY_FILE" "Summary"
append_safe "| \`07-services.md\` | System services and hardware interfaces |" "$SUMMARY_FILE" "Summary"
append_safe "| \`08-software.md\` | Installed packages and system software |" "$SUMMARY_FILE" "Summary"
append_safe "| \`09-play-integrity.md\` | Play Integrity analysis and recommendations |" "$SUMMARY_FILE" "Summary"
append_safe "| \`export.log\` | Export process log and error details |" "$SUMMARY_FILE" "Summary"
append_safe "" "$SUMMARY_FILE" "Summary"

log_success "Output structure initialized"

# ---------- DEVICE INFORMATION ----------
log_info "Collecting device information..."

# Initialize device info file
append_safe "# Device Information" "$DEVICE_FILE" "Device Info"
append_safe "" "$DEVICE_FILE" "Device Info"
append_safe "**Analysis Date:** $(date 2>/dev/null || echo 'Date unavailable')" "$DEVICE_FILE" "Device Info"
append_safe "" "$DEVICE_FILE" "Device Info"
append_safe "## Device Specifications" "$DEVICE_FILE" "Device Info"
append_safe "" "$DEVICE_FILE" "Device Info"
append_safe "| Property | Value |" "$DEVICE_FILE" "Device Info"
append_safe "|----------|-------|" "$DEVICE_FILE" "Device Info"

# Collect device properties with error handling
if command -v getprop >/dev/null 2>&1; then
    MODEL=$(getprop ro.product.model 2>/dev/null || echo 'N/A')
    DEVICE=$(getprop ro.product.device 2>/dev/null || echo 'N/A')
    BRAND=$(getprop ro.product.brand 2>/dev/null || echo 'N/A')
    MANUFACTURER=$(getprop ro.product.manufacturer 2>/dev/null || echo 'N/A')
    
    append_safe "| Model | $MODEL |" "$DEVICE_FILE" "Device Info"
    append_safe "| Device | $DEVICE |" "$DEVICE_FILE" "Device Info"
    append_safe "| Brand | $BRAND |" "$DEVICE_FILE" "Device Info"
    append_safe "| Manufacturer | $MANUFACTURER |" "$DEVICE_FILE" "Device Info"
    append_safe "| Fingerprint | $(getprop ro.build.fingerprint 2>/dev/null || echo 'N/A') |" "$DEVICE_FILE" "Device Info"
    append_safe "| Build ID | $(getprop ro.build.id 2>/dev/null || echo 'N/A') |" "$DEVICE_FILE" "Device Info"
    append_safe "| Android Version | $(getprop ro.build.version.release 2>/dev/null || echo 'N/A') |" "$DEVICE_FILE" "Device Info"
    append_safe "| Security Patch | $(getprop ro.build.version.security_patch 2>/dev/null || echo 'N/A') |" "$DEVICE_FILE" "Device Info"
    append_safe "| ROM Type | $(getprop ro.boot.verifiedbootstate 2>/dev/null || echo 'N/A') |" "$DEVICE_FILE" "Device Info"
    
    # Update summary with key device info
    append_safe "## Device Summary" "$SUMMARY_FILE" "Summary"
    append_safe "" "$SUMMARY_FILE" "Summary"
    append_safe "**Device:** $BRAND $MODEL ($DEVICE)" "$SUMMARY_FILE" "Summary"
    append_safe "**Android:** $(getprop ro.build.version.release 2>/dev/null || echo 'N/A')" "$SUMMARY_FILE" "Summary"
    append_safe "**Security Patch:** $(getprop ro.build.version.security_patch 2>/dev/null || echo 'N/A')" "$SUMMARY_FILE" "Summary"
    append_safe "" "$SUMMARY_FILE" "Summary"
else
    append_safe "| Error | getprop command not available |" "$DEVICE_FILE" "Device Info"
fi

append_safe "" "$DEVICE_FILE" "Device Info"
log_success "Device information saved to 01-device-info.md"

# ---------- KERNEL AND ROOT ANALYSIS ----------
log_info "Analyzing kernel and root status..."

# Initialize kernel/root file
append_safe "# Kernel and Root Analysis" "$KERNEL_FILE" "Kernel Info"
append_safe "" "$KERNEL_FILE" "Kernel Info"
append_safe "## Kernel Information" "$KERNEL_FILE" "Kernel Info"
append_safe "" "$KERNEL_FILE" "Kernel Info"
append_safe "| Property | Value |" "$KERNEL_FILE" "Kernel Info"
append_safe "|----------|-------|" "$KERNEL_FILE" "Kernel Info"

if [ -r "/proc/version" ]; then
    KERNEL_VERSION=$(cat /proc/version 2>/dev/null || echo 'N/A')
    append_safe "| Kernel Version | $KERNEL_VERSION |" "$KERNEL_FILE" "Kernel Info"
else
    append_safe "| Kernel Version | /proc/version not readable |" "$KERNEL_FILE" "Kernel Info"
fi

if command -v uname >/dev/null 2>&1; then
    append_safe "| Architecture | $(uname -m 2>/dev/null || echo 'N/A') |" "$KERNEL_FILE" "Kernel Info"
    append_safe "| Host | $(uname -n 2>/dev/null || echo 'N/A') |" "$KERNEL_FILE" "Kernel Info"
else
    append_safe "| Architecture | uname not available |" "$KERNEL_FILE" "Kernel Info"
fi

append_safe "" "$KERNEL_FILE" "Kernel Info"
append_safe "## Root Management Status" "$KERNEL_FILE" "Kernel Info"
append_safe "" "$KERNEL_FILE" "Kernel Info"

# Check for root management systems
ROOT_STATUS="Unknown"
ROOT_DETAILS="No root management detected"

# Check for Magisk
if [ -f "/data/adb/magisk/magisk" ] || [ -f "/data/adb/magisk/magisk64" ] || [ -d "/data/adb/modules" ]; then
    ROOT_STATUS="Magisk"
    if command -v magisk >/dev/null 2>&1; then
        MAGISK_VERSION=$(magisk -c 2>/dev/null || echo 'Version unknown')
        ROOT_DETAILS="Magisk active (Version: $MAGISK_VERSION)"
    else
        ROOT_DETAILS="Magisk files detected but command not in PATH"
    fi
    
    # Comprehensive Magisk module analysis
    if [ -d "/data/adb/modules" ]; then
        MODULE_COUNT=$(ls -1 /data/adb/modules 2>/dev/null | wc -l)
        ROOT_DETAILS="$ROOT_DETAILS - $MODULE_COUNT modules installed"
        
        append_safe "" "$KERNEL_FILE" "Kernel Info"
        append_safe "## Magisk Modules Analysis" "$KERNEL_FILE" "Kernel Info"
        append_safe "" "$KERNEL_FILE" "Kernel Info"
        append_safe "**Total Modules:** $MODULE_COUNT" "$KERNEL_FILE" "Kernel Info"
        append_safe "" "$KERNEL_FILE" "Kernel Info"
        
        # Detailed module information
        append_safe "### Installed Modules" "$KERNEL_FILE" "Kernel Info"
        append_safe "" "$KERNEL_FILE" "Kernel Info"
        append_safe "| Module ID | Name | Version | Author | Status |" "$KERNEL_FILE" "Kernel Info"
        append_safe "|-----------|------|---------|--------|--------|" "$KERNEL_FILE" "Kernel Info"
        
        for module_dir in /data/adb/modules/*/; do
            if [ -d "$module_dir" ]; then
                MODULE_ID=$(basename "$module_dir")
                
                # Read module.prop if exists
                if [ -f "${module_dir}module.prop" ]; then
                    MODULE_NAME=$(grep "^name=" "${module_dir}module.prop" 2>/dev/null | cut -d'=' -f2- || echo "Unknown")
                    MODULE_VERSION=$(grep "^version=" "${module_dir}module.prop" 2>/dev/null | cut -d'=' -f2- || echo "Unknown")
                    MODULE_AUTHOR=$(grep "^author=" "${module_dir}module.prop" 2>/dev/null | cut -d'=' -f2- || echo "Unknown")
                else
                    MODULE_NAME="Unknown"
                    MODULE_VERSION="Unknown"
                    MODULE_AUTHOR="Unknown"
                fi
                
                # Check if module is disabled
                if [ -f "${module_dir}disable" ] || [ -f "${module_dir}.disable" ]; then
                    MODULE_STATUS="Disabled"
                elif [ -f "${module_dir}remove" ]; then
                    MODULE_STATUS="Pending Removal"
                else
                    MODULE_STATUS="Active"
                fi
                
                append_safe "| $MODULE_ID | $MODULE_NAME | $MODULE_VERSION | $MODULE_AUTHOR | $MODULE_STATUS |" "$KERNEL_FILE" "Kernel Info"
            fi
        done
        
        append_safe "" "$KERNEL_FILE" "Kernel Info"
        
        # Check for specific popular modules and their configurations
        append_safe "### Module Configurations" "$KERNEL_FILE" "Kernel Info"
        append_safe "" "$KERNEL_FILE" "Kernel Info"
        
        # Check for PIF (Play Integrity Fix)
        if [ -d "/data/adb/modules/pif" ] || [ -d "/data/adb/modules/playintegrityfix" ]; then
            append_safe "#### Play Integrity Fix (PIF)" "$KERNEL_FILE" "Kernel Info"
            if [ -f "/data/adb/pif.json" ]; then
                append_safe "\`\`\`json" "$KERNEL_FILE" "Kernel Info"
                head -n 20 /data/adb/pif.json >> "$KERNEL_FILE" 2>/dev/null || append_safe "Configuration file not readable" "$KERNEL_FILE" "Kernel Info"
                append_safe "\`\`\`" "$KERNEL_FILE" "Kernel Info"
            else
                append_safe "**Status:** Installed but no configuration found" "$KERNEL_FILE" "Kernel Info"
            fi
            append_safe "" "$KERNEL_FILE" "Kernel Info"
        fi
        
        # Check for TrickyStore
        if [ -d "/data/adb/modules/trickystore" ]; then
            append_safe "#### TrickyStore" "$KERNEL_FILE" "Kernel Info"
            if [ -f "/data/adb/tricky_store/keybox.xml" ]; then
                append_safe "**Status:** Active with keybox configuration" "$KERNEL_FILE" "Kernel Info"
                append_safe "**Keybox file:** Present" "$KERNEL_FILE" "Kernel Info"
            else
                append_safe "**Status:** Installed but no keybox found" "$KERNEL_FILE" "Kernel Info"
            fi
            append_safe "" "$KERNEL_FILE" "Kernel Info"
        fi
        
        # Check for LSPosed/EdXposed
        if [ -d "/data/adb/modules/lsposed" ] || [ -d "/data/adb/modules/edxposed" ]; then
            append_safe "#### LSPosed/EdXposed Framework" "$KERNEL_FILE" "Kernel Info"
            if [ -d "/data/adb/lspd" ]; then
                LSPOSED_VERSION=$(grep "versionName" /data/adb/lspd/manager.apk 2>/dev/null || echo "Unknown")
                append_safe "**Status:** Active" "$KERNEL_FILE" "Kernel Info"
                append_safe "**Version:** $LSPOSED_VERSION" "$KERNEL_FILE" "Kernel Info"
            else
                append_safe "**Status:** Installed" "$KERNEL_FILE" "Kernel Info"
            fi
            append_safe "" "$KERNEL_FILE" "Kernel Info"
        fi
        
        # Check for Zygisk modules
        if [ -d "/data/adb/modules/zygisk_lsposed" ] || [ -d "/data/adb/modules/shamiko" ] || [ -d "/data/adb/modules/zygisksu" ]; then
            append_safe "#### Zygisk Modules" "$KERNEL_FILE" "Kernel Info"
            
            # Shamiko
            if [ -d "/data/adb/modules/shamiko" ]; then
                append_safe "**Shamiko:** Installed (MagiskHide replacement)" "$KERNEL_FILE" "Kernel Info"
                if [ -f "/data/adb/shamiko/whitelist" ]; then
                    WHITELIST_COUNT=$(wc -l < /data/adb/shamiko/whitelist 2>/dev/null || echo "0")
                    append_safe "  - Whitelist entries: $WHITELIST_COUNT" "$KERNEL_FILE" "Kernel Info"
                fi
            fi
            
            # LSPosed Zygisk
            if [ -d "/data/adb/modules/zygisk_lsposed" ]; then
                append_safe "**LSPosed Zygisk:** Installed" "$KERNEL_FILE" "Kernel Info"
            fi
            
            append_safe "" "$KERNEL_FILE" "Kernel Info"
        fi
        
        # Check for SUSFS
        if [ -d "/data/adb/modules/susfs" ]; then
            append_safe "#### SUSFS (Simple Userspace FS)" "$KERNEL_FILE" "Kernel Info"
            if [ -f "/data/adb/susfs/config" ]; then
                append_safe "**Status:** Active with configuration" "$KERNEL_FILE" "Kernel Info"
                CONFIG_LINES=$(wc -l < /data/adb/susfs/config 2>/dev/null || echo "0")
                append_safe "**Config entries:** $CONFIG_LINES" "$KERNEL_FILE" "Kernel Info"
            else
                append_safe "**Status:** Installed but no configuration found" "$KERNEL_FILE" "Kernel Info"
            fi
            append_safe "" "$KERNEL_FILE" "Kernel Info"
        fi
        
        # Check for other common modules
        append_safe "#### Other Notable Modules" "$KERNEL_FILE" "Kernel Info"
        
        # Universal SafetyNet Fix
        if [ -d "/data/adb/modules/safetynetfix" ] || [ -d "/data/adb/modules/universal-safetynet-fix" ]; then
            append_safe "**SafetyNet Fix:** Installed" "$KERNEL_FILE" "Kernel Info"
        fi
        
        # MagiskHide Props Config
        if [ -d "/data/adb/modules/MagiskHidePropsConf" ]; then
            append_safe "**MagiskHide Props Config:** Installed" "$KERNEL_FILE" "Kernel Info"
        fi
        
        # Busybox
        if [ -d "/data/adb/modules/busybox-ndk" ]; then
            append_safe "**BusyBox NDK:** Installed" "$KERNEL_FILE" "Kernel Info"
        fi
        
        append_safe "" "$KERNEL_FILE" "Kernel Info"
    fi
    
# Check for KernelSU
elif [ -f "/data/adb/ksu/ksu" ] || [ -f "/data/adb/ksud" ] || [ -f "/sys/fs/ksu/version" ]; then
    ROOT_STATUS="KernelSU"
    if [ -f "/sys/fs/ksu/version" ]; then
        KSU_VERSION=$(cat /sys/fs/ksu/version 2>/dev/null || echo 'Version unknown')
        ROOT_DETAILS="KernelSU active (Version: $KSU_VERSION)"
    elif command -v su >/dev/null 2>&1; then
        KSU_VERSION=$(su -c "ksud --version" 2>/dev/null || echo 'Version unknown')
        ROOT_DETAILS="KernelSU active (Version: $KSU_VERSION)"
    else
        ROOT_DETAILS="KernelSU files detected but su not available"
    fi
    
    # Check for KernelSU modules
    append_safe "" "$KERNEL_FILE" "Kernel Info"
    append_safe "## KernelSU Modules Analysis" "$KERNEL_FILE" "Kernel Info"
    append_safe "" "$KERNEL_FILE" "Kernel Info"
    
    if [ -d "/data/adb/modules" ]; then
        KSU_MODULE_COUNT=$(ls -1 /data/adb/modules 2>/dev/null | wc -l)
        append_safe "**Total Modules:** $KSU_MODULE_COUNT" "$KERNEL_FILE" "Kernel Info"
        append_safe "" "$KERNEL_FILE" "Kernel Info"
        
        # List KernelSU modules with basic info
        append_safe "### Installed KernelSU Modules" "$KERNEL_FILE" "Kernel Info"
        append_safe "" "$KERNEL_FILE" "Kernel Info"
        
        for module_dir in /data/adb/modules/*/; do
            if [ -d "$module_dir" ]; then
                MODULE_ID=$(basename "$module_dir")
                append_safe "- **$MODULE_ID**" "$KERNEL_FILE" "Kernel Info"
                
                if [ -f "${module_dir}module.prop" ]; then
                    MODULE_NAME=$(grep "^name=" "${module_dir}module.prop" 2>/dev/null | cut -d'=' -f2- || echo "Unknown")
                    append_safe "  - Name: $MODULE_NAME" "$KERNEL_FILE" "Kernel Info"
                fi
            fi
        done
    else
        append_safe "**Status:** No modules directory found" "$KERNEL_FILE" "Kernel Info"
    fi
    
    append_safe "" "$KERNEL_FILE" "Kernel Info"
# Check for SuperSU
elif [ -f "/system/xbin/su" ] || [ -f "/system/bin/su" ] || [ -f "/sbin/su" ]; then
    ROOT_STATUS="Traditional Root"
    if command -v su >/dev/null 2>&1; then
        SU_VERSION=$(su --version 2>/dev/null || echo 'Version unknown')
        ROOT_DETAILS="Traditional su binary found (Version: $SU_VERSION)"
    else
        ROOT_DETAILS="su binary detected but not functional"
    fi
# Check if su command exists without specific binaries
elif command -v su >/dev/null 2>&1; then
    ROOT_STATUS="Generic Root"
    ROOT_DETAILS="su command available but source unknown"
fi

append_safe "**Status:** $ROOT_STATUS" "$KERNEL_FILE" "Kernel Info"
append_safe "" "$KERNEL_FILE" "Kernel Info"
append_safe "**Details:** $ROOT_DETAILS" "$KERNEL_FILE" "Kernel Info"
append_safe "" "$KERNEL_FILE" "Kernel Info"

# Add root status to summary
append_safe "**Root Status:** $ROOT_STATUS" "$SUMMARY_FILE" "Summary"
append_safe "" "$SUMMARY_FILE" "Summary"

log_success "Kernel and root analysis saved to 02-kernel-root.md"

# ---------- BOOT AND SECURITY ----------
log_info "Checking boot and security status..."

# Initialize boot security file
append_safe "# Boot and Security Analysis" "$BOOT_FILE" "Boot Security"
append_safe "" "$BOOT_FILE" "Boot Security"
append_safe "## Boot State" "$BOOT_FILE" "Boot Security"
append_safe "" "$BOOT_FILE" "Boot Security"
append_safe "| Property | Value |" "$BOOT_FILE" "Boot Security"
append_safe "|----------|-------|" "$BOOT_FILE" "Boot Security"

if command -v getprop >/dev/null 2>&1; then
    append_safe "| Boot Slot | $(getprop ro.boot.slot_suffix 2>/dev/null || echo 'N/A') |" "$BOOT_FILE" "Boot Security"
    append_safe "| Verified Boot | $(getprop ro.boot.verifiedbootstate 2>/dev/null || echo 'N/A') |" "$BOOT_FILE" "Boot Security"
    append_safe "| Boot Mode | $(getprop ro.bootmode 2>/dev/null || echo 'N/A') |" "$BOOT_FILE" "Boot Security"
    append_safe "| Secure Boot | $(getprop ro.secureboot.lockstate 2>/dev/null || echo 'N/A') |" "$BOOT_FILE" "Boot Security"
    append_safe "| VBMeta State | $(getprop ro.boot.vbmeta.device_state 2>/dev/null || echo 'N/A') |" "$BOOT_FILE" "Boot Security"
else
    append_safe "| Error | getprop command not available |" "$BOOT_FILE" "Boot Security"
fi

append_safe "" "$BOOT_FILE" "Boot Security"
append_safe "## Security Features" "$BOOT_FILE" "Boot Security"
append_safe "" "$BOOT_FILE" "Boot Security"
append_safe "| Feature | Status |" "$BOOT_FILE" "Boot Security"
append_safe "|---------|--------|" "$BOOT_FILE" "Boot Security"

if command -v getprop >/dev/null 2>&1; then
    append_safe "| SELinux | $(getprop ro.boot.selinux 2>/dev/null || echo 'N/A') |" "$BOOT_FILE" "Boot Security"
    append_safe "| ADB Secure | $(getprop ro.adb.secure 2>/dev/null || echo 'N/A') |" "$BOOT_FILE" "Boot Security"
    append_safe "| Debug | $(getprop ro.debuggable 2>/dev/null || echo 'N/A') |" "$BOOT_FILE" "Boot Security"
fi

# VBMeta analysis if available
append_safe "" "$BOOT_FILE" "Boot Security"
append_safe "## VBMeta Analysis" "$BOOT_FILE" "Boot Security"
append_safe "" "$BOOT_FILE" "Boot Security"

VBMETA_FOUND=false
if [ -f "/sys/firmware/devicetree/base/vbmeta/0/algorithm" ]; then
    ALGO=$(cat /sys/firmware/devicetree/base/vbmeta/0/algorithm 2>/dev/null || echo 'N/A')
    append_safe "**Algorithm:** $ALGO" "$BOOT_FILE" "Boot Security"
    VBMETA_FOUND=true
fi

if [ -f "/sys/firmware/devicetree/base/vbmeta/0/digest" ]; then
    DIGEST=$(cat /sys/firmware/devicetree/base/vbmeta/0/digest 2>/dev/null || echo 'N/A')
    append_safe "**Digest:** $DIGEST" "$BOOT_FILE" "Boot Security"
    VBMETA_FOUND=true
fi

if [ "$VBMETA_FOUND" = false ]; then
    append_safe "**Status:** VBMeta information not accessible" "$BOOT_FILE" "Boot Security"
    append_safe "*Note: This is normal on some devices/ROMs*" "$BOOT_FILE" "Boot Security"
fi

append_safe "" "$BOOT_FILE" "Boot Security"
log_success "Boot and security analysis saved to 03-boot-security.md"

# ---------- ROOT MODULES ANALYSIS ----------
log_info "Analyzing root modules and configurations..."

# Initialize root modules file
append_safe "# Root Modules and Configurations" "$ROOT_MODULES_FILE" "Root Modules"
append_safe "" "$ROOT_MODULES_FILE" "Root Modules"
append_safe "**Analysis Date:** $(date 2>/dev/null || echo 'Date unavailable')" "$ROOT_MODULES_FILE" "Root Modules"
append_safe "" "$ROOT_MODULES_FILE" "Root Modules"

# Check if we have root management detected
if [ "$ROOT_STATUS" = "Magisk" ] || [ "$ROOT_STATUS" = "KernelSU" ]; then
    append_safe "## Root Management: $ROOT_STATUS" "$ROOT_MODULES_FILE" "Root Modules"
    append_safe "" "$ROOT_MODULES_FILE" "Root Modules"
    append_safe "**Status:** $ROOT_DETAILS" "$ROOT_MODULES_FILE" "Root Modules"
    append_safe "" "$ROOT_MODULES_FILE" "Root Modules"
    
    if [ -d "/data/adb/modules" ]; then
        MODULE_COUNT=$(ls -1 /data/adb/modules 2>/dev/null | wc -l)
        append_safe "## Module Overview" "$ROOT_MODULES_FILE" "Root Modules"
        append_safe "" "$ROOT_MODULES_FILE" "Root Modules"
        append_safe "**Total Modules:** $MODULE_COUNT" "$ROOT_MODULES_FILE" "Root Modules"
        append_safe "" "$ROOT_MODULES_FILE" "Root Modules"
        
        # Detailed module analysis
        append_safe "## Detailed Module Analysis" "$ROOT_MODULES_FILE" "Root Modules"
        append_safe "" "$ROOT_MODULES_FILE" "Root Modules"
        
        for module_dir in /data/adb/modules/*/; do
            if [ -d "$module_dir" ]; then
                MODULE_ID=$(basename "$module_dir")
                append_safe "### Module: $MODULE_ID" "$ROOT_MODULES_FILE" "Root Modules"
                append_safe "" "$ROOT_MODULES_FILE" "Root Modules"
                
                # Read module.prop details
                if [ -f "${module_dir}module.prop" ]; then
                    append_safe "**Configuration (module.prop):**" "$ROOT_MODULES_FILE" "Root Modules"
                    append_safe "\`\`\`" "$ROOT_MODULES_FILE" "Root Modules"
                    cat "${module_dir}module.prop" >> "$ROOT_MODULES_FILE" 2>/dev/null || append_safe "Unable to read module.prop" "$ROOT_MODULES_FILE" "Root Modules"
                    append_safe "\`\`\`" "$ROOT_MODULES_FILE" "Root Modules"
                else
                    append_safe "**Status:** No module.prop found" "$ROOT_MODULES_FILE" "Root Modules"
                fi
                
                # Check module status
                if [ -f "${module_dir}disable" ]; then
                    append_safe "**Module Status:** Disabled" "$ROOT_MODULES_FILE" "Root Modules"
                elif [ -f "${module_dir}remove" ]; then
                    append_safe "**Module Status:** Scheduled for removal" "$ROOT_MODULES_FILE" "Root Modules"
                else
                    append_safe "**Module Status:** Active" "$ROOT_MODULES_FILE" "Root Modules"
                fi
                
                # List important files
                append_safe "" "$ROOT_MODULES_FILE" "Root Modules"
                append_safe "**Module Files:**" "$ROOT_MODULES_FILE" "Root Modules"
                if [ -f "${module_dir}service.sh" ]; then
                    append_safe "- service.sh (Boot service script)" "$ROOT_MODULES_FILE" "Root Modules"
                fi
                if [ -f "${module_dir}post-fs-data.sh" ]; then
                    append_safe "- post-fs-data.sh (Early boot script)" "$ROOT_MODULES_FILE" "Root Modules"
                fi
                if [ -d "${module_dir}system" ]; then
                    SYS_FILES=$(find "${module_dir}system" -type f 2>/dev/null | wc -l)
                    append_safe "- system/ directory ($SYS_FILES files)" "$ROOT_MODULES_FILE" "Root Modules"
                fi
                if [ -f "${module_dir}sepolicy.rule" ]; then
                    append_safe "- sepolicy.rule (SELinux policy modifications)" "$ROOT_MODULES_FILE" "Root Modules"
                fi
                
                append_safe "" "$ROOT_MODULES_FILE" "Root Modules"
                append_safe "---" "$ROOT_MODULES_FILE" "Root Modules"
                append_safe "" "$ROOT_MODULES_FILE" "Root Modules"
            fi
        done
        
        # Special configurations for popular modules
        append_safe "## Popular Module Configurations" "$ROOT_MODULES_FILE" "Root Modules"
        append_safe "" "$ROOT_MODULES_FILE" "Root Modules"
        
        # PIF (Play Integrity Fix) detailed analysis
        if [ -f "/data/adb/pif.json" ] || [ -f "/data/local/tmp/pif.json" ]; then
            append_safe "### Play Integrity Fix (PIF) Configuration" "$ROOT_MODULES_FILE" "Root Modules"
            append_safe "" "$ROOT_MODULES_FILE" "Root Modules"
            
            for pif_file in "/data/adb/pif.json" "/data/local/tmp/pif.json"; do
                if [ -f "$pif_file" ]; then
                    append_safe "**Configuration file:** $pif_file" "$ROOT_MODULES_FILE" "Root Modules"
                    append_safe "\`\`\`json" "$ROOT_MODULES_FILE" "Root Modules"
                    cat "$pif_file" >> "$ROOT_MODULES_FILE" 2>/dev/null || append_safe "Unable to read PIF configuration" "$ROOT_MODULES_FILE" "Root Modules"
                    append_safe "\`\`\`" "$ROOT_MODULES_FILE" "Root Modules"
                    append_safe "" "$ROOT_MODULES_FILE" "Root Modules"
                    break
                fi
            done
        fi
        
        # TrickyStore configuration
        if [ -d "/data/adb/tricky_store" ]; then
            append_safe "### TrickyStore Configuration" "$ROOT_MODULES_FILE" "Root Modules"
            append_safe "" "$ROOT_MODULES_FILE" "Root Modules"
            
            if [ -f "/data/adb/tricky_store/keybox.xml" ]; then
                append_safe "**Keybox Configuration:**" "$ROOT_MODULES_FILE" "Root Modules"
                append_safe "\`\`\`xml" "$ROOT_MODULES_FILE" "Root Modules"
                head -n 20 "/data/adb/tricky_store/keybox.xml" >> "$ROOT_MODULES_FILE" 2>/dev/null || append_safe "Unable to read keybox configuration" "$ROOT_MODULES_FILE" "Root Modules"
                append_safe "\`\`\`" "$ROOT_MODULES_FILE" "Root Modules"
            fi
            
            if [ -f "/data/adb/tricky_store/target.txt" ]; then
                append_safe "" "$ROOT_MODULES_FILE" "Root Modules"
                append_safe "**Target Applications:**" "$ROOT_MODULES_FILE" "Root Modules"
                append_safe "\`\`\`" "$ROOT_MODULES_FILE" "Root Modules"
                cat "/data/adb/tricky_store/target.txt" >> "$ROOT_MODULES_FILE" 2>/dev/null || append_safe "Unable to read target configuration" "$ROOT_MODULES_FILE" "Root Modules"
                append_safe "\`\`\`" "$ROOT_MODULES_FILE" "Root Modules"
            fi
            append_safe "" "$ROOT_MODULES_FILE" "Root Modules"
        fi
        
        # Shamiko configuration
        if [ -f "/data/adb/shamiko/whitelist" ]; then
            append_safe "### Shamiko Hide Configuration" "$ROOT_MODULES_FILE" "Root Modules"
            append_safe "" "$ROOT_MODULES_FILE" "Root Modules"
            append_safe "**Whitelist Entries:**" "$ROOT_MODULES_FILE" "Root Modules"
            append_safe "\`\`\`" "$ROOT_MODULES_FILE" "Root Modules"
            cat "/data/adb/shamiko/whitelist" >> "$ROOT_MODULES_FILE" 2>/dev/null || append_safe "Unable to read whitelist" "$ROOT_MODULES_FILE" "Root Modules"
            append_safe "\`\`\`" "$ROOT_MODULES_FILE" "Root Modules"
            append_safe "" "$ROOT_MODULES_FILE" "Root Modules"
        fi
        
        # SUSFS configuration
        if [ -f "/data/adb/susfs/config" ]; then
            append_safe "### SUSFS Configuration" "$ROOT_MODULES_FILE" "Root Modules"
            append_safe "" "$ROOT_MODULES_FILE" "Root Modules"
            append_safe "**SUSFS Config:**" "$ROOT_MODULES_FILE" "Root Modules"
            append_safe "\`\`\`" "$ROOT_MODULES_FILE" "Root Modules"
            cat "/data/adb/susfs/config" >> "$ROOT_MODULES_FILE" 2>/dev/null || append_safe "Unable to read SUSFS configuration" "$ROOT_MODULES_FILE" "Root Modules"
            append_safe "\`\`\`" "$ROOT_MODULES_FILE" "Root Modules"
            append_safe "" "$ROOT_MODULES_FILE" "Root Modules"
        fi
        
        # LSPosed module list
        if [ -d "/data/adb/lspd" ]; then
            append_safe "### LSPosed Framework" "$ROOT_MODULES_FILE" "Root Modules"
            append_safe "" "$ROOT_MODULES_FILE" "Root Modules"
            
            # Try to get LSPosed module info
            if [ -f "/data/adb/lspd/config/modules.list" ]; then
                append_safe "**Active Modules:**" "$ROOT_MODULES_FILE" "Root Modules"
                append_safe "\`\`\`" "$ROOT_MODULES_FILE" "Root Modules"
                cat "/data/adb/lspd/config/modules.list" >> "$ROOT_MODULES_FILE" 2>/dev/null || append_safe "Unable to read LSPosed modules" "$ROOT_MODULES_FILE" "Root Modules"
                append_safe "\`\`\`" "$ROOT_MODULES_FILE" "Root Modules"
            else
                append_safe "**Status:** LSPosed detected but no module list found" "$ROOT_MODULES_FILE" "Root Modules"
            fi
            append_safe "" "$ROOT_MODULES_FILE" "Root Modules"
        fi
        
    else
        append_safe "## No Modules Directory" "$ROOT_MODULES_FILE" "Root Modules"
        append_safe "" "$ROOT_MODULES_FILE" "Root Modules"
        append_safe "No /data/adb/modules directory found." "$ROOT_MODULES_FILE" "Root Modules"
        append_safe "" "$ROOT_MODULES_FILE" "Root Modules"
    fi
    
else
    append_safe "## No Root Management Detected" "$ROOT_MODULES_FILE" "Root Modules"
    append_safe "" "$ROOT_MODULES_FILE" "Root Modules"
    append_safe "No supported root management system (Magisk/KernelSU) was detected." "$ROOT_MODULES_FILE" "Root Modules"
    append_safe "This file would contain detailed root module configurations if root access was available." "$ROOT_MODULES_FILE" "Root Modules"
    append_safe "" "$ROOT_MODULES_FILE" "Root Modules"
fi

log_success "Root modules analysis saved to 04-root-modules.md"

# ---------- HARDWARE INFORMATION ----------
log_info "Collecting hardware information..."

# Initialize hardware file
append_safe "# Hardware Information" "$HARDWARE_FILE" "Hardware Info"
append_safe "" "$HARDWARE_FILE" "Hardware Info"
append_safe "## CPU Information" "$HARDWARE_FILE" "Hardware Info"
append_safe "" "$HARDWARE_FILE" "Hardware Info"

if [ -r "/proc/cpuinfo" ]; then
    # Extract key CPU details
    CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^[[:space:]]*//' 2>/dev/null || echo 'N/A')
    CPU_CORES=$(grep "processor" /proc/cpuinfo | wc -l 2>/dev/null || echo 'N/A')
    CPU_ARCH=$(grep "Features" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^[[:space:]]*//' 2>/dev/null || echo 'N/A')
    
    append_safe "| Property | Value |" "$HARDWARE_FILE" "Hardware Info"
    append_safe "|----------|-------|" "$HARDWARE_FILE" "Hardware Info"
    append_safe "| Model | $CPU_MODEL |" "$HARDWARE_FILE" "Hardware Info"
    append_safe "| Cores | $CPU_CORES |" "$HARDWARE_FILE" "Hardware Info"
    append_safe "| Architecture | $CPU_ARCH |" "$HARDWARE_FILE" "Hardware Info"
else
    append_safe "**Error:** /proc/cpuinfo not accessible" "$HARDWARE_FILE" "Hardware Info"
fi

append_safe "" "$HARDWARE_FILE" "Hardware Info"
append_safe "## Memory Information" "$HARDWARE_FILE" "Hardware Info"
append_safe "" "$HARDWARE_FILE" "Hardware Info"

if [ -r "/proc/meminfo" ]; then
    # Extract key memory details
    MEM_TOTAL=$(grep "MemTotal" /proc/meminfo | awk '{print $2 " " $3}' 2>/dev/null || echo 'N/A')
    MEM_FREE=$(grep "MemFree" /proc/meminfo | awk '{print $2 " " $3}' 2>/dev/null || echo 'N/A')
    MEM_AVAILABLE=$(grep "MemAvailable" /proc/meminfo | awk '{print $2 " " $3}' 2>/dev/null || echo 'N/A')
    
    append_safe "| Property | Value |" "$HARDWARE_FILE" "Hardware Info"
    append_safe "|----------|-------|" "$HARDWARE_FILE" "Hardware Info"
    append_safe "| Total Memory | $MEM_TOTAL |" "$HARDWARE_FILE" "Hardware Info"
    append_safe "| Free Memory | $MEM_FREE |" "$HARDWARE_FILE" "Hardware Info"
    append_safe "| Available Memory | $MEM_AVAILABLE |" "$HARDWARE_FILE" "Hardware Info"
else
    append_safe "**Error:** /proc/meminfo not accessible" "$HARDWARE_FILE" "Hardware Info"
fi

append_safe "" "$HARDWARE_FILE" "Hardware Info"
log_success "Hardware information saved to 05-hardware.md"

# ---------- STORAGE AND PARTITIONS ----------
log_info "Collecting storage and partition information..."

# Initialize storage file
append_safe "# Storage and Partitions" "$STORAGE_FILE" "Storage Info"
append_safe "" "$STORAGE_FILE" "Storage Info"
append_safe "## Storage Overview" "$STORAGE_FILE" "Storage Info"
append_safe "" "$STORAGE_FILE" "Storage Info"

# Disk usage
append_safe "### Disk Usage" "$STORAGE_FILE" "Storage Info"
append_safe "\`\`\`" "$STORAGE_FILE" "Storage Info"
if command -v df >/dev/null 2>&1; then
    df -h >> "$STORAGE_FILE" 2>/dev/null || append_safe "Disk usage information unavailable" "$STORAGE_FILE" "Storage Info"
else
    append_safe "df command not available" "$STORAGE_FILE" "Storage Info"
fi
append_safe "\`\`\`" "$STORAGE_FILE" "Storage Info"
append_safe "" "$STORAGE_FILE" "Storage Info"

# Partition information
append_safe "### Partition Table" "$STORAGE_FILE" "Storage Info"
append_safe "\`\`\`" "$STORAGE_FILE" "Storage Info"

PART_INFO_FOUND=false

# Try lsblk first
if command -v lsblk >/dev/null 2>&1; then
    if lsblk >> "$STORAGE_FILE" 2>/dev/null && [ $? -eq 0 ]; then
        PART_INFO_FOUND=true
    fi
fi

# Fallback to /proc/partitions if lsblk failed
if [ "$PART_INFO_FOUND" = false ] && [ -r "/proc/partitions" ]; then
    append_safe "=== /proc/partitions ===" "$STORAGE_FILE" "Storage Info"
    if cat /proc/partitions >> "$STORAGE_FILE" 2>/dev/null; then
        PART_INFO_FOUND=true
    fi
fi

if [ "$PART_INFO_FOUND" = false ]; then
    append_safe "Partition information unavailable" "$STORAGE_FILE" "Storage Info"
fi

append_safe "\`\`\`" "$STORAGE_FILE" "Storage Info"
append_safe "" "$STORAGE_FILE" "Storage Info"

# Mount points
append_safe "### Mount Points" "$STORAGE_FILE" "Storage Info"
append_safe "\`\`\`" "$STORAGE_FILE" "Storage Info"
if [ -r "/proc/mounts" ]; then
    cat /proc/mounts >> "$STORAGE_FILE" 2>/dev/null || append_safe "Unable to read mount information" "$STORAGE_FILE" "Storage Info"
else
    append_safe "/proc/mounts not accessible" "$STORAGE_FILE" "Storage Info"
fi
append_safe "\`\`\`" "$STORAGE_FILE" "Storage Info"
append_safe "" "$STORAGE_FILE" "Storage Info"

log_success "Storage information saved to 06-storage.md"

# Add missing sections to complete the 7-services file
append_safe "# System Services and Hardware" "$SERVICES_FILE" "Services Info"
append_safe "" "$SERVICES_FILE" "Services Info"
append_safe "## Hardware Services" "$SERVICES_FILE" "Services Info"
append_safe "" "$SERVICES_FILE" "Services Info"

if command -v dumpsys >/dev/null 2>&1; then
    # Battery information
    append_safe "### Battery Information" "$SERVICES_FILE" "Services Info"
    append_safe "\`\`\`" "$SERVICES_FILE" "Services Info"
    dumpsys battery 2>/dev/null | head -n 30 >> "$SERVICES_FILE" || append_safe "Battery service unavailable" "$SERVICES_FILE" "Services Info"
    append_safe "\`\`\`" "$SERVICES_FILE" "Services Info"
    append_safe "" "$SERVICES_FILE" "Services Info"
    
    # Display information
    append_safe "### Display Information" "$SERVICES_FILE" "Services Info"
    append_safe "\`\`\`" "$SERVICES_FILE" "Services Info"
    dumpsys display 2>/dev/null | head -n 30 >> "$SERVICES_FILE" || append_safe "Display service unavailable" "$SERVICES_FILE" "Services Info"
    append_safe "\`\`\`" "$SERVICES_FILE" "Services Info"
    append_safe "" "$SERVICES_FILE" "Services Info"
else
    append_safe "**Error:** dumpsys command not available" "$SERVICES_FILE" "Services Info"
fi

log_success "System services saved to 07-services.md"

# ---------- SOFTWARE AND APPLICATIONS ----------
log_info "Collecting software and application information..."

# Initialize software file
append_safe "# Software and Applications" "$SOFTWARE_FILE" "Software Info"
append_safe "" "$SOFTWARE_FILE" "Software Info"
append_safe "## Installed Packages" "$SOFTWARE_FILE" "Software Info"
append_safe "" "$SOFTWARE_FILE" "Software Info"

if command -v pm >/dev/null 2>&1; then
    PACKAGE_COUNT=$(pm list packages 2>/dev/null | wc -l)
    append_safe "**Total Packages:** $PACKAGE_COUNT" "$SOFTWARE_FILE" "Software Info"
    append_safe "" "$SOFTWARE_FILE" "Software Info"
    append_safe "\`\`\`" "$SOFTWARE_FILE" "Software Info"
    pm list packages 2>/dev/null | head -n 100 >> "$SOFTWARE_FILE" || append_safe "Package list unavailable" "$SOFTWARE_FILE" "Software Info"
    append_safe "\`\`\`" "$SOFTWARE_FILE" "Software Info"
else
    append_safe "**Error:** pm command not available" "$SOFTWARE_FILE" "Software Info"
fi

append_safe "" "$SOFTWARE_FILE" "Software Info"
append_safe "## System Activities" "$SOFTWARE_FILE" "Software Info"
append_safe "" "$SOFTWARE_FILE" "Software Info"

if command -v dumpsys >/dev/null 2>&1; then
    append_safe "\`\`\`" "$SOFTWARE_FILE" "Software Info"
    dumpsys activity activities 2>/dev/null | head -n 50 >> "$SOFTWARE_FILE" || append_safe "Activity manager information unavailable" "$SOFTWARE_FILE" "Software Info"
    append_safe "\`\`\`" "$SOFTWARE_FILE" "Software Info"
else
    append_safe "**Error:** dumpsys command not available" "$SOFTWARE_FILE" "Software Info"
fi

append_safe "" "$SOFTWARE_FILE" "Software Info"
log_success "Software information saved to 07-software.md"

# ---------- PLAY INTEGRITY ANALYSIS ----------
log_info "Analyzing Play Integrity status and generating recommendations..."

# Initialize Play Integrity file
append_safe "# Play Integrity Analysis & Root Hiding Guide" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "**Analysis Date:** $(date 2>/dev/null || echo 'Date unavailable')" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "**Device:** $BRAND $MODEL" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "**Root Status:** $ROOT_STATUS" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"

append_safe "## Current System Analysis" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"

# Analyze current system state for Play Integrity
append_safe "### Device Security State" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "| Property | Value | Impact |" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "|----------|-------|--------|" "$PLAY_INTEGRITY_FILE" "Play Integrity"

# Boot state analysis
if command -v getprop >/dev/null 2>&1; then
    BOOT_STATE=$(getprop ro.boot.verifiedbootstate 2>/dev/null || echo 'N/A')
    VBMETA_STATE=$(getprop ro.boot.vbmeta.device_state 2>/dev/null || echo 'N/A')
    BOOTLOADER_STATE=$(getprop ro.boot.flash.locked 2>/dev/null || echo 'N/A')
    SELINUX_STATE=$(getprop ro.boot.selinux 2>/dev/null || echo 'N/A')
    DEBUG_STATE=$(getprop ro.debuggable 2>/dev/null || echo 'N/A')
    
    # Analyze boot state impact
    if [ "$BOOT_STATE" = "green" ]; then
        BOOT_IMPACT="[GOOD] Verified boot intact"
    elif [ "$BOOT_STATE" = "yellow" ]; then
        BOOT_IMPACT="[MODERATE] Custom key used"
    elif [ "$BOOT_STATE" = "orange" ]; then
        BOOT_IMPACT="[HIGH] Bootloader unlocked"
    elif [ "$BOOT_STATE" = "red" ]; then
        BOOT_IMPACT="[CRITICAL] Boot verification failed"
    else
        BOOT_IMPACT="[UNKNOWN] Unable to determine"
    fi
    
    append_safe "| Verified Boot | $BOOT_STATE | $BOOT_IMPACT |" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "| VBMeta State | $VBMETA_STATE | $([ "$VBMETA_STATE" = "locked" ] && echo "[GOOD] Locked" || echo "[HIGH] Unlocked/Modified") |" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "| Bootloader | $BOOTLOADER_STATE | $([ "$BOOTLOADER_STATE" = "1" ] && echo "[GOOD] Locked" || echo "[HIGH] Unlocked") |" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "| SELinux | $SELINUX_STATE | $([ "$SELINUX_STATE" = "enforcing" ] && echo "[GOOD] Enforcing" || echo "[MODERATE] Permissive") |" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "| Debug State | $DEBUG_STATE | $([ "$DEBUG_STATE" = "0" ] && echo "[GOOD] Production build" || echo "[MODERATE] Debug build") |" "$PLAY_INTEGRITY_FILE" "Play Integrity"
else
    append_safe "| Error | getprop not available | [CRITICAL] Cannot analyze |" "$PLAY_INTEGRITY_FILE" "Play Integrity"
fi

append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"

# Root detection analysis
append_safe "### Root Detection Analysis" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"

if [ "$ROOT_STATUS" = "Magisk" ]; then
    append_safe "**Root Management:** Magisk detected" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "**Hide Method:** MagiskHide/Zygisk required for Play Integrity" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    
    # Check for hiding modules
    HIDE_MODULES_FOUND=false
    
    if [ -d "/data/adb/modules/shamiko" ]; then
        append_safe "✅ **Shamiko** - Advanced hiding module detected" "$PLAY_INTEGRITY_FILE" "Play Integrity"
        HIDE_MODULES_FOUND=true
        if [ -f "/data/adb/shamiko/whitelist" ]; then
            WHITELIST_COUNT=$(wc -l < /data/adb/shamiko/whitelist 2>/dev/null || echo "0")
            append_safe "   - Whitelist entries: $WHITELIST_COUNT" "$PLAY_INTEGRITY_FILE" "Play Integrity"
        fi
    fi
    
    if [ -d "/data/adb/modules/zygisksu" ]; then
        append_safe "✅ **ZygiskSU** - Root hiding module detected" "$PLAY_INTEGRITY_FILE" "Play Integrity"
        HIDE_MODULES_FOUND=true
    fi
    
    if [ "$HIDE_MODULES_FOUND" = false ]; then
        append_safe "⚠️ **No hiding modules detected** - Root may be easily detectable" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    fi
    
elif [ "$ROOT_STATUS" = "KernelSU" ]; then
    append_safe "**Root Management:** KernelSU detected" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "**Hide Method:** KernelSU built-in hiding + modules required" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"
else
    append_safe "**Root Management:** $ROOT_STATUS" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "**Risk Level:** High - Non-standard root may be easily detectable" "$PLAY_INTEGRITY_FILE" "Play Integrity"
fi

append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"

# Play Integrity module analysis
append_safe "### Play Integrity Modules Analysis" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"

PIF_DETECTED=false
TRICKY_DETECTED=false
SAFETY_DETECTED=false

# Check for PIF
if [ -d "/data/adb/modules/pif" ] || [ -d "/data/adb/modules/playintegrityfix" ] || [ -f "/data/adb/pif.json" ]; then
    append_safe "✅ **Play Integrity Fix (PIF)** - Detected" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    PIF_DETECTED=true
    
    if [ -f "/data/adb/pif.json" ]; then
        append_safe "   - Configuration: /data/adb/pif.json found" "$PLAY_INTEGRITY_FILE" "Play Integrity"
        
        # Analyze PIF configuration
        if grep -q "DEVICE" /data/adb/pif.json 2>/dev/null; then
            append_safe "   - Status: Device spoofing configured" "$PLAY_INTEGRITY_FILE" "Play Integrity"
        fi
        if grep -q "FINGERPRINT" /data/adb/pif.json 2>/dev/null; then
            append_safe "   - Status: Fingerprint spoofing configured" "$PLAY_INTEGRITY_FILE" "Play Integrity"
        fi
    else
        append_safe "   - Configuration: ⚠️ No pif.json found - may not be active" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    fi
fi

# Check for TrickyStore
if [ -d "/data/adb/modules/trickystore" ]; then
    append_safe "✅ **TrickyStore** - Advanced attestation spoofing detected" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    TRICKY_DETECTED=true
    
    if [ -f "/data/adb/tricky_store/keybox.xml" ]; then
        append_safe "   - Keybox: Configured" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    else
        append_safe "   - Keybox: ⚠️ Not configured - TrickyStore inactive" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    fi
    
    if [ -f "/data/adb/tricky_store/target.txt" ]; then
        TARGET_COUNT=$(wc -l < /data/adb/tricky_store/target.txt 2>/dev/null || echo "0")
        append_safe "   - Target apps: $TARGET_COUNT configured" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    fi
fi

# Check for SafetyNet Fix
if [ -d "/data/adb/modules/safetynetfix" ] || [ -d "/data/adb/modules/universal-safetynet-fix" ]; then
    append_safe "✅ **SafetyNet Fix** - Legacy module detected" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "   - Note: May not work with current Play Integrity API" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    SAFETY_DETECTED=true
fi

if [ "$PIF_DETECTED" = false ] && [ "$TRICKY_DETECTED" = false ] && [ "$SAFETY_DETECTED" = false ]; then
    append_safe "❌ **No Play Integrity modules detected**" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "   - Risk: Very High - Device will fail integrity checks" "$PLAY_INTEGRITY_FILE" "Play Integrity"
fi

append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"

# Comprehensive recommendations
append_safe "## 🎯 Comprehensive Play Integrity Strategy" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"

append_safe "### Priority 1: Essential Modules" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"

if [ "$PIF_DETECTED" = false ]; then
    append_safe "#### 🔥 CRITICAL: Install Play Integrity Fix (PIF)" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "**Module:** Play Integrity Fix (osm0sis)" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "**Download:** https://github.com/osm0sis/PlayIntegrityFix/releases" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "**Installation:**" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "1. Download latest PIF module zip" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "2. Install via Magisk Manager" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "3. Reboot device" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "4. Configure /data/adb/pif.json with valid fingerprint" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    
    append_safe "**Sample PIF Configuration:**" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "\`\`\`json" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "{" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "  \"DEVICE\": \"redfin\"," "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "  \"FINGERPRINT\": \"google/redfin/redfin:13/TQ3A.230805.001/10316531:user/release-keys\"," "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "  \"MODEL\": \"Pixel 5\"," "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "  \"MANUFACTURER\": \"Google\"," "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "  \"BRAND\": \"google\"," "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "  \"PRODUCT\": \"redfin\"," "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "  \"SECURITY_PATCH\": \"2023-08-05\"," "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "  \"FIRST_API_LEVEL\": \"30\"" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "}" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "\`\`\`" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"
fi

if [ "$TRICKY_DETECTED" = false ]; then
    append_safe "#### ⭐ RECOMMENDED: Install TrickyStore" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "**Module:** TrickyStore (5ec1cff)" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "**Purpose:** Advanced hardware attestation spoofing" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "**Download:** https://github.com/5ec1cff/TrickyStore/releases" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "**Requirements:**" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "- Valid keybox.xml file" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "- Target application configuration" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "- LSPosed framework (recommended)" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"
fi

append_safe "### Priority 2: Root Hiding" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"

if [ "$ROOT_STATUS" = "Magisk" ]; then
    if [ ! -d "/data/adb/modules/shamiko" ]; then
        append_safe "#### 🛡️ Install Shamiko (Advanced MagiskHide)" "$PLAY_INTEGRITY_FILE" "Play Integrity"
        append_safe "**Module:** Shamiko" "$PLAY_INTEGRITY_FILE" "Play Integrity"
        append_safe "**Download:** https://github.com/LSPosed/LSPosed.github.io/releases" "$PLAY_INTEGRITY_FILE" "Play Integrity"
        append_safe "**Features:**" "$PLAY_INTEGRITY_FILE" "Play Integrity"
        append_safe "- Advanced root hiding capabilities" "$PLAY_INTEGRITY_FILE" "Play Integrity"
        append_safe "- Per-app whitelist configuration" "$PLAY_INTEGRITY_FILE" "Play Integrity"
        append_safe "- Better than legacy MagiskHide" "$PLAY_INTEGRITY_FILE" "Play Integrity"
        append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    fi
    
    append_safe "#### ⚙️ Magisk Configuration" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "**Essential Settings:**" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "1. Enable Zygisk in Magisk settings" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "2. Disable Magisk app in Play Store apps if needed" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "3. Use DenyList for sensitive applications" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "4. Hide Magisk app icon/name if required" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    
elif [ "$ROOT_STATUS" = "KernelSU" ]; then
    append_safe "#### ⚙️ KernelSU Configuration" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "**Essential Settings:**" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "1. Enable root hiding in KernelSU manager" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "2. Configure app whitelist/blacklist" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "3. Install compatible hiding modules" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "4. Consider SUSFS module for advanced hiding" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"
fi

# Device-specific recommendations
append_safe "### Priority 3: Device-Specific Considerations" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"

# Analyze device characteristics for specific recommendations
if command -v getprop >/dev/null 2>&1; then
    ANDROID_VERSION=$(getprop ro.build.version.release 2>/dev/null || echo 'N/A')
    SECURITY_PATCH=$(getprop ro.build.version.security_patch 2>/dev/null || echo 'N/A')
    DEVICE_NAME=$(getprop ro.product.device 2>/dev/null || echo 'N/A')
    
    append_safe "#### 📱 Current Device Analysis" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "**Android Version:** $ANDROID_VERSION" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "**Security Patch:** $SECURITY_PATCH" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "**Device Codename:** $DEVICE_NAME" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    
    # Android version specific recommendations
    append_safe "#### 🔧 Version-Specific Recommendations" "$PLAY_INTEGRITY_FILE" "Play Integrity"
    case "$ANDROID_VERSION" in
        "14"*)
            append_safe "**Android 14 Considerations:**" "$PLAY_INTEGRITY_FILE" "Play Integrity"
            append_safe "- Use latest PIF with Android 14 support" "$PLAY_INTEGRITY_FILE" "Play Integrity"
            append_safe "- TrickyStore highly recommended for hardware attestation" "$PLAY_INTEGRITY_FILE" "Play Integrity"
            append_safe "- Ensure modules are Android 14 compatible" "$PLAY_INTEGRITY_FILE" "Play Integrity"
            ;;
        "13"*)
            append_safe "**Android 13 Considerations:**" "$PLAY_INTEGRITY_FILE" "Play Integrity"
            append_safe "- Most stable for Play Integrity bypass" "$PLAY_INTEGRITY_FILE" "Play Integrity"
            append_safe "- PIF + TrickyStore combination works well" "$PLAY_INTEGRITY_FILE" "Play Integrity"
            append_safe "- Good module compatibility" "$PLAY_INTEGRITY_FILE" "Play Integrity"
            ;;
        "12"*)
            append_safe "**Android 12 Considerations:**" "$PLAY_INTEGRITY_FILE" "Play Integrity"
            append_safe "- Legacy PIF versions may work better" "$PLAY_INTEGRITY_FILE" "Play Integrity"
            append_safe "- Check module compatibility with Android 12" "$PLAY_INTEGRITY_FILE" "Play Integrity"
            ;;
        *)
            append_safe "**General Recommendations:**" "$PLAY_INTEGRITY_FILE" "Play Integrity"
            append_safe "- Verify module compatibility with Android $ANDROID_VERSION" "$PLAY_INTEGRITY_FILE" "Play Integrity"
            append_safe "- Use latest stable versions of bypass modules" "$PLAY_INTEGRITY_FILE" "Play Integrity"
            ;;
    esac
    append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"
fi

# Testing and validation section
append_safe "### Priority 4: Testing & Validation" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "#### 🧪 Recommended Testing Apps" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "1. **Play Integrity API Checker** - Test current status" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "2. **YASNAC** (Yet Another SafetyNet Attestation Checker)" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "3. **TB Checker** - Root detection testing" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "4. **Banking apps** - Real-world testing" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"

append_safe "#### 📋 Testing Checklist" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "- [ ] Basic integrity: MEETS_BASIC_INTEGRITY" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "- [ ] Device integrity: MEETS_DEVICE_INTEGRITY" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "- [ ] Strong integrity: MEETS_STRONG_INTEGRITY" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "- [ ] Hardware attestation: Valid certificate chain" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "- [ ] App-specific testing: Banking/payment apps work" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"

# Troubleshooting section
append_safe "### 🔧 Advanced Troubleshooting" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "#### Common Issues & Solutions" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "**Issue: MEETS_BASIC_INTEGRITY fails**" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "- Solution: Install/reconfigure PIF module" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "- Check: Valid fingerprint in pif.json" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "- Verify: Module is active and loaded" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"

append_safe "**Issue: MEETS_DEVICE_INTEGRITY fails**" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "- Solution: Enable better root hiding (Shamiko/DenyList)" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "- Check: Bootloader status and verified boot" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "- Consider: Stock ROM fingerprint spoofing" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"

append_safe "**Issue: MEETS_STRONG_INTEGRITY fails**" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "- Solution: Install TrickyStore with valid keybox" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "- Requirement: Hardware attestation spoofing" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "- Note: Most difficult to achieve on rooted devices" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"

append_safe "#### 🔗 Useful Resources" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "- **XDA Forums:** Play Integrity discussion threads" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "- **GitHub:** Module repositories and issue trackers" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "- **Telegram:** Magisk and root hiding communities" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "- **Reddit:** r/Magisk and r/Android communities" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"

append_safe "---" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "*This analysis is generated automatically based on your current system state.*" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "*Recommendations may need adjustment based on your specific device and use case.*" "$PLAY_INTEGRITY_FILE" "Play Integrity"
append_safe "" "$PLAY_INTEGRITY_FILE" "Play Integrity"

log_success "Play Integrity analysis saved to 09-play-integrity.md"

# Add missing sections to complete the 6-services file
append_safe "# System Services and Hardware" "$SERVICES_FILE" "Services Info"
append_safe "" "$SERVICES_FILE" "Services Info"
append_safe "## Hardware Services" "$SERVICES_FILE" "Services Info"
append_safe "" "$SERVICES_FILE" "Services Info"

if command -v dumpsys >/dev/null 2>&1; then
    # Battery information
    append_safe "### Battery Information" "$SERVICES_FILE" "Services Info"
    append_safe "\`\`\`" "$SERVICES_FILE" "Services Info"
    dumpsys battery 2>/dev/null | head -n 30 >> "$SERVICES_FILE" || append_safe "Battery service unavailable" "$SERVICES_FILE" "Services Info"
    append_safe "\`\`\`" "$SERVICES_FILE" "Services Info"
    append_safe "" "$SERVICES_FILE" "Services Info"
    
    # Display information
    append_safe "### Display Information" "$SERVICES_FILE" "Services Info"
    append_safe "\`\`\`" "$SERVICES_FILE" "Services Info"
    dumpsys display 2>/dev/null | head -n 30 >> "$SERVICES_FILE" || append_safe "Display service unavailable" "$SERVICES_FILE" "Services Info"
    append_safe "\`\`\`" "$SERVICES_FILE" "Services Info"
    append_safe "" "$SERVICES_FILE" "Services Info"
else
    append_safe "**Error:** dumpsys command not available" "$SERVICES_FILE" "Services Info"
fi

log_success "System services saved to 06-services.md"

# ---------- FINALIZE AND COMPLETE ----------
log_info "Finalizing analysis and generating summary..."

# Complete summary file
append_safe "" "$SUMMARY_FILE" "Summary"
append_safe "## Analysis Complete" "$SUMMARY_FILE" "Summary"
append_safe "" "$SUMMARY_FILE" "Summary"
append_safe "**Export completed:** $(date 2>/dev/null || echo 'Date unavailable')" "$SUMMARY_FILE" "Summary"
append_safe "**Total files generated:** 10" "$SUMMARY_FILE" "Summary"
append_safe "" "$SUMMARY_FILE" "Summary"
append_safe "*Generated by Speccy v4.1 - Universal Android Device Analyzer with Root Module Analysis*" "$SUMMARY_FILE" "Summary"

echo ""
echo "════════════════════════════════════════════════════════"
echo "[SUCCESS] SPECCY ANALYSIS COMPLETED"
echo "════════════════════════════════════════════════════════"

# Verify all files were created
TOTAL_FILES=0
for file in "$SUMMARY_FILE" "$DEVICE_FILE" "$KERNEL_FILE" "$BOOT_FILE" "$ROOT_MODULES_FILE" "$HARDWARE_FILE" "$STORAGE_FILE" "$SERVICES_FILE" "$SOFTWARE_FILE" "$PLAY_INTEGRITY_FILE"; do
    if [ -f "$file" ]; then
        TOTAL_FILES=$((TOTAL_FILES + 1))
    else
        log_warning "File not created: $file"
    fi
done

echo "[INFO] Output Directory: $OUTPUT_DIR"
echo "[INFO] Files Generated: $TOTAL_FILES/10"
echo "[INFO] Analysis ID: ${DATE_STR}"
echo ""
echo "[INFO] Generated Files:"
echo "  • 00-SUMMARY.md        - Analysis overview and file index"
echo "  • 01-device-info.md    - Device specifications and build info"
echo "  • 02-kernel-root.md    - Kernel version and root management"
echo "  • 03-boot-security.md  - Boot state and security features"
echo "  • 04-root-modules.md   - Root modules, configs, and settings"
echo "  • 05-hardware.md       - CPU, memory, and hardware details"
echo "  • 06-storage.md        - Storage, partitions, and file systems"
echo "  • 07-services.md       - System services and hardware interfaces"
echo "  • 08-software.md       - Installed packages and applications"
echo "  • 09-play-integrity.md - Play Integrity analysis and recommendations"
echo "  • export.log           - Analysis process log and error details"
echo ""

if [ "$TOTAL_FILES" -eq 10 ]; then
    echo "[SUCCESS] All files generated successfully!"
    echo "[INFO] View summary: cat \"$SUMMARY_FILE\""
    echo "[INFO] Browse directory: ls -la \"$OUTPUT_DIR\""
else
    log_warning "Some files were not generated - check export.log for details"
fi

echo ""
log_success "Speccy analysis completed successfully!"
