# 🛠️ Tools Collection

A curated collection of lightweight, practical tools for development, testing, security research, and automation tasks. Built for personal use, learning, and quick problem-solving.

## 📋 Table of Contents
- [Tools Overview](#tools-overview)
- [Installation](#installation)
- [Usage](#usage)
- [Contributing](#contributing)
- [License](#license)

## 🔧 Tools Overview

| Tool | Description | Platform | Type |
|------|-------------|----------|------|
| [`aes256-encrypt-decrypt`](#aes256-encrypt-decrypt) | Encrypts & decrypts `.txt` files with AES-256 encryption | Cross-platform | Security |
| [`http-header-grabber`](#http-header-grabber) | Pulls all HTTP headers from a target URL | Cross-platform | Networking |
| [`quick-subdomain-finder`](#quick-subdomain-finder) | Finds subdomains from a target domain in seconds | Cross-platform | Reconnaissance |
| [`port-scan-lite`](#port-scan-lite) | Minimalistic Python port scanner for network discovery | Cross-platform | Networking |
| [`jwt-decode-cli`](#jwt-decode-cli) | Decode and analyze JWT tokens from the command line | Cross-platform | Security |
| [`speccy.sh`](#speccy-android-device-analyzer) | Complete Android device specification and state analyzer | Android (Root) | System Analysis |

## 📖 Detailed Tool Documentation

### speccy (Android Device Analyzer)
**File:** `speccy.sh`
**Platform:** Android (requires root access)
**Purpose:** Comprehensive Android device state analysis for ROM development, debugging, and security research.

#### Features
- **Device Information:** Model, build fingerprint, Android version, security patch level
- **Kernel & Root Analysis:** Kernel version, universal root detection with detailed configuration
- **Root Module Analysis:** Deep inspection of Magisk/KernelSU modules with configuration details
- **Module Configurations:** PIF settings, TrickyStore keybox, Shamiko whitelist, LSPosed modules, SUSFS config
- **Popular Module Detection:** Automatic detection of PIF, TrickyStore, Shamiko, LSPosed, SUSFS, SafetyNet Fix
- **Play Integrity Analysis:** Comprehensive analysis and recommendations for achieving strong integrity
- **Boot & Security:** Verified boot state, VBMeta analysis, bootloader status, SELinux configuration
- **Hardware Analysis:** CPU specs, memory details, storage overview, partition analysis
- **System Services:** Battery management, display configuration, hardware services
- **Software Inventory:** Package analysis, activity manager, system software overview

#### New in v4.2
- **🆕 Play Integrity Analysis:** Comprehensive guide for achieving strong integrity on rooted devices
- **🆕 LLM-Friendly Format:** Structured output for AI-assisted troubleshooting and recommendations
- **🆕 Root Hiding Strategy:** Step-by-step configuration guide for PIF, TrickyStore, and Shamiko
- **🆕 Device-Specific Recommendations:** Tailored advice based on Android version and device characteristics
- **🆕 Testing Methodology:** Built-in checklist and validation steps for integrity bypass
- **🆕 Troubleshooting Guide:** Common issues and solutions with detailed resolution steps

#### Previous Updates (v4.1)
- **🆕 Dedicated Root Modules File:** Complete module analysis with configurations
- **🆕 Deep Module Inspection:** Full module.prop reading, status detection, file analysis
- **🆕 Configuration Export:** PIF.json, TrickyStore keybox, Shamiko whitelist, SUSFS config
- **🆕 Multi-File Output:** Organized files instead of single overwhelming document
- **🆕 Professional Interface:** Clean logging without emojis, structured progress indicators

#### Output Structure
The tool creates a comprehensive analysis directory:
```
Speccy-YYYYMMDDHHMM/
├── 00-SUMMARY.md         # Analysis overview and file index  
├── 01-device-info.md     # Device specifications and build info
├── 02-kernel-root.md     # Kernel version and root management
├── 03-boot-security.md   # Boot state and security features
├── 04-root-modules.md    # Root modules, configs, and settings
├── 05-hardware.md        # CPU, memory, and hardware details
├── 06-storage.md         # Storage, partitions, and file systems
├── 07-services.md        # System services and hardware interfaces
├── 08-software.md        # Installed packages and applications
├── 09-play-integrity.md  # Play Integrity analysis and recommendations
└── export.log           # Analysis process log and error details
```

#### Compatibility
Works with any rooted Android device including:
- **Magisk** rooted devices (with comprehensive module analysis)
- **KernelSU** rooted devices (with module detection and configuration export)
- **SuperSU** legacy rooted devices
- **Custom ROM** devices with built-in root
- **AOSP** builds with root access

#### Usage
```bash
# One-liner installation and execution  
curl -fsSL https://zahidoverflow.github.io/tools/speccy.sh | sudo bash

# Or download and run locally
wget https://zahidoverflow.github.io/tools/speccy.sh
chmod +x speccy.sh
./speccy.sh

# View results
cd Speccy-*
cat 00-SUMMARY.md                    # Overview and file index
cat 04-root-modules.md               # Root modules and configurations
cat 09-play-integrity.md            # Play Integrity analysis and recommendations
ls -la                               # Browse all generated files
```

# Or manual execution
chmod +x speccy.sh
su -c './speccy.sh'

# Output will be saved as:
# speccy-YYYYMMDDHHMM.md (e.g., speccy-202511181746.md)
```

#### Use Cases
- ROM debugging and kernel analysis
- Root detection research and false-positive verification
- Device state snapshots for bug reporting
- Hardware compatibility verification for ROM ports
- Security research and integrity analysis
- Magisk module compatibility testing
- **Play Integrity troubleshooting** for banking apps and security-sensitive applications
- **Root hiding configuration** optimization for maximum stealth
- **LLM-assisted analysis** for personalized recommendations and solution strategies

## 🚀 Installation

### Prerequisites
- For Android tools: Rooted Android device with shell access
- For Python tools: Python 3.6+
- For general tools: Basic Unix-like environment (Linux/macOS/WSL)

### Quick Setup
```bash
# Clone the repository
git clone https://github.com/zahidoverflow/tools.git
cd tools

# Make scripts executable (Unix-like systems)
chmod +x *.sh

# For Android tools, transfer to device:
adb push speccy.sh /sdcard/
```

## 📱 Usage Examples

### Android Device Analysis
```bash
# One-liner execution
curl -fsSL https://zahidoverflow.github.io/tools/speccy.sh | sudo bash

# Manual execution
adb shell
su
cd /sdcard/
chmod +x speccy.sh
./speccy.sh

# View the generated report
cat /sdcard/Download/speccy-202511181746.md
```

## 🎯 Project Philosophy

This collection focuses on:
- **Simplicity**: Tools that solve specific problems efficiently
- **Learning**: Understanding how systems work under the hood
- **Automation**: Reducing repetitive manual tasks
- **Reconnaissance**: Helper tools for security research and analysis
- **Clean Code**: Readable, reusable implementations for learning

## 🤝 Contributing

Contributions are welcome! This is primarily a personal learning repository, but if you have:
- Bug fixes or improvements
- Additional lightweight tools
- Documentation enhancements
- Usage examples

Please feel free to open an issue or submit a pull request.

## 📄 License

This project is licensed under the terms specified in the [LICENSE](LICENSE) file.

## ⚠️ Disclaimer

These tools are intended for educational purposes, authorized testing, and personal use only. Always ensure you have proper authorization before using any security or reconnaissance tools on systems you don't own.

---

**Note**: This is an evolving collection. New tools and improvements are added regularly based on learning experiences and practical needs.
