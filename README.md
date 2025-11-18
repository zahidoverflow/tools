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
- **Kernel Analysis:** Kernel version, KernelSU status, boot state verification
- **System State:** CPU info, memory usage, storage analysis, partition layout
- **Hardware Details:** Display configuration, battery status, sensors, telephony
- **Security Context:** Verified boot state, vbmeta digest, root environment
- **Package Analysis:** Complete list of installed packages and system activities

#### Usage
```bash
# Make executable
chmod +x speccy.sh

# Run the analyzer (requires root)
su -c './speccy.sh'

# Output will be saved to:
# /sdcard/Download/phone_spec.txt
```

#### Use Cases
- ROM debugging and kernel analysis
- Root detection research and false-positive verification
- Device state snapshots for bug reporting
- Hardware compatibility verification
- Security research and integrity analysis

#### Output Format
The tool generates a comprehensive report including:
- Device specifications and build information
- Kernel and root environment details
- Hardware configuration and sensor data
- System state and partition information
- Complete package listings

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
# Transfer and run speccy.sh on Android device
adb shell
su
cd /sdcard/
chmod +x speccy.sh
./speccy.sh

# View the generated report
cat /sdcard/Download/phone_spec.txt
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
