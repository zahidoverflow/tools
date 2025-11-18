#!/system/bin/sh
# ============================================================
#  Speccy (v2)
#  Author: zahidoverflow
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
#
#  Output: /sdcard/Download/phone_spec.txt
# ============================================================

OUT="/sdcard/Download/phone_spec.md"

echo "# Android Device Specification Report" > "$OUT"
echo "" >> "$OUT"
echo "**Generated:** $(date)" >> "$OUT"
echo "**Export Tool:** KRYPTON v3" >> "$OUT"
echo "" >> "$OUT"

# ---------- BASIC DEVICE IDENTITIES ----------
echo "## 📱 Device Information" >> "$OUT"
echo "" >> "$OUT"
echo "| Property | Value |" >> "$OUT"
echo "|----------|-------|" >> "$OUT"
echo "| Model | $(getprop ro.product.model) |" >> "$OUT"
echo "| Device | $(getprop ro.product.device) |" >> "$OUT"
echo "| Brand | $(getprop ro.product.brand) |" >> "$OUT"
echo "| Manufacturer | $(getprop ro.product.manufacturer) |" >> "$OUT"
echo "| Fingerprint | $(getprop ro.build.fingerprint) |" >> "$OUT"
echo "| Build ID | $(getprop ro.build.id) |" >> "$OUT"
echo "| Android Version | $(getprop ro.build.version.release) |" >> "$OUT"
echo "| Security Patch | $(getprop ro.build.version.security_patch) |" >> "$OUT"
echo "| ROM Type | $(getprop ro.boot.verifiedbootstate) |" >> "$OUT"
echo "" >> "$OUT"

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

# ---------- END ----------
echo "---" >> "$OUT"
echo "" >> "$OUT"
echo "**Report generated by speccy.sh**" >> "$OUT"
echo "**Export completed:** $(date)" >> "$OUT"

echo "🔥 Spec exported to: $OUT"
echo "📖 Displaying content in terminal:"
echo ""
cat "$OUT"
