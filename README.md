# 🚀 TorNetManager

*A PowerShell-based Network Management Tool with Tor Integration*

![TorNetManager](https://img.shields.io/badge/PowerShell-Network--Tool-blue.svg)
![Tor](https://img.shields.io/badge/Tor-Privacy-purple.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## 📜 Description

**TorNetManager** is an advanced **PowerShell-based network management** tool designed to help users **monitor, configure, and anonymize their network connections**. It provides features such as:
- **Network discovery**
- **MAC address spoofing**
- **IP renewal**
- **Tor-based anonymity**
- **Port scanning**

The project integrates **Tor** to allow users to dynamically change their public IP address, making it an essential tool for **privacy-conscious users, ethical hackers, and developers**.

---

## 🔹 Features

### Core Features
✅ **View Network Details** – Get **local & public IP, MAC address, and gateway**
✅ **Change MAC Address** – Generate and apply a **random MAC**
✅ **Renew Local IP** – Reset DHCP IP settings for a **fresh IP allocation**
✅ **Tor IP Changer** – **Automate Tor circuit switching** to obtain a new **public IP**
✅ **Firewall & Security Check** – Configure Windows **Firewall to allow Tor**
✅ **Network Discovery** – Scan **active devices on the local network**
✅ **Port Scanner** – Scan common **open ports** on target IPs
✅ **Router Manager** – Restart your **router remotely** (if supported)
✅ **Tor Process Management** – Ensure **only one Tor instance is running**

### Advanced Capabilities
- 🌐 Multiple IP verification services
- 🔄 Automatic circuit regeneration
- 📡 DHCP management
- 🛡️ Comprehensive security checks
- 🔍 Device fingerprinting
- 📊 Network statistics

---

## 📂 Folder Structure
```
TorNetManager/
│── NetworkManager.ps1     # Main PowerShell script
│── README.md             # Documentation
│── LICENSE              # License information
│── config/
│   ├── torrc           # Tor configuration file (auto-generated)
│── scripts/
│   ├── utilities.ps1    # Helper functions
│   ├── setup.ps1        # Installation script
│── docs/
│   ├── user_guide.md    # User documentation
```

---

## 📖 Setup & Usage

### 📥 1️⃣ Installation
Clone the repository:
```powershell
git clone https://github.com/yourusername/TorNetManager.git
cd TorNetManager
```

### 🛠 2️⃣ Setup
Run the setup script to configure dependencies:
```powershell
.\scripts\setup.ps1
```

### 🌐 3️⃣ Running the Network Manager
Launch the main script:
```powershell
.\NetworkManager.ps1
```

Then, **choose an option** from the menu to perform the desired network operation.

---

## ⚙️ Configuration

### 🛠 **Tor Configuration**
`TorNetManager` automatically generates a valid `torrc` file with the following settings:
```ini
# Basic Configuration
ControlPort 9051
CookieAuthentication 1
CookieAuthFile C:\Users\yourusername\AppData\Roaming\tor\control_auth_cookie
DataDirectory C:\Users\yourusername\AppData\Roaming\tor

# Performance Settings
MaxCircuitDirtiness 10
NewCircuitPeriod 10
EnforceDistinctSubnets 1
NumEntryGuards 8
UseEntryGuards 1
CircuitStreamTimeout 30
ClientOnly 1
```

If `torrc` is missing, the script will create it automatically.

### 🔥 **Firewall Configuration**
- Automatic verification of Tor's ControlPort (9051)
- Windows Firewall rule management
- Administrator privileges required for modifications
- SOCKS proxy configuration (port 9050)

### 🔒 **Security Features**
- Cookie-based authentication
- Circuit isolation
- IP verification through multiple services
- Connection security checks

---

## 🛡️ Security & Permissions

- **Administrator Rights Required**
  - Firewall configuration
  - Network adapter settings
  - MAC address changes
  - IP configuration

- **Tor Security**
  - Automated process management
  - Authentication handling
  - Circuit verification
  - Exit node management

- **Best Practices**
  - Regular IP rotation
  - Circuit isolation
  - Connection verification
  - Process monitoring

---

## 🔧 Troubleshooting

### Common Issues
1. **Tor Connection Failed**
   - Verify Tor installation
   - Check firewall rules
   - Confirm SOCKS proxy status

2. **IP Change Issues**
   - Wait for circuit establishment
   - Verify exit node configuration
   - Check network connectivity

3. **Permission Errors**
   - Run as Administrator
   - Verify file permissions
   - Check authentication cookies

# 🔧 TorTroubleshooter

A comprehensive PowerShell-based diagnostic and management tool for Tor connections.

## 🚀 Features

### Diagnostics & Monitoring
- ✅ Full System Diagnostics
- 🔍 Tor Installation Verification
- 📊 Configuration Analysis
- 💻 Process Monitoring
- 🌐 Network Connectivity Tests

### IP Management
- 🔄 Automated IP Rotation
- ✨ Multiple IP Verification Services
- 📡 Circuit Creation Monitoring
- 🛡️ Exit Node Management
- 📊 Progress Tracking

### Security Features
- 🔐 Cookie Authentication
- 🛡️ GeoIP Configuration
- 🔥 Firewall Management
- 🔍 Port Verification
- 🚦 Connection Status Monitoring

## 📋 Menu Options

1. **Run Full Diagnostics**
   - Complete system check
   - Configuration verification
   - Network testing
   - Authentication validation

2. **Check Tor Installation**
   - Version verification
   - Path validation
   - Binary integrity check

3. **Verify Tor Configuration**
   - Config file analysis
   - Required settings check
   - Path verification
   - Default config creation if missing

4. **Check Tor Process**
   - Process status monitoring
   - Resource usage tracking
   - Multiple instance prevention

5. **Test Control Port**
   - Port accessibility check
   - Connection testing
   - Firewall verification

6. **Verify Authentication**
   - Cookie validation
   - Permission checking
   - Path verification

7. **Check Network Connectivity**
   - Internet connection testing
   - Tor network accessibility
   - DNS resolution check

8. **Test IP Change Functionality**
   - Current IP verification
   - Circuit creation
   - IP rotation
   - Change confirmation

9. **Restart Tor**
   - Safe process termination
   - Clean restart
   - Status verification

10. **Enhance Exit Node Configuration**
    - GeoIP setup
    - Exit node selection
    - Circuit parameters
    - Performance optimization

## 🛠️ Usage

```powershell
# Launch the troubleshooter
.\TorTroubleshooter.ps1

# Follow the interactive menu to:
# - Diagnose issues
# - Configure Tor
# - Manage IP changes
# - Monitor performance
```

## ⚙️ Configuration

### Tor Settings
```ini
# Basic Configuration
ControlPort 9051
CookieAuthentication 1
CookieAuthFile [path]\control_auth_cookie
DataDirectory [path]

# Circuit Configuration
MaxCircuitDirtiness 30
NewCircuitPeriod 10
EnforceDistinctSubnets 1
```

### Exit Node Configuration
```ini
# Node Selection
ExitNodes {us},{de},{nl},{fr},{gb},{se},{ch},{ca},{jp},{au}
StrictNodes 1
ExcludeNodes BadExit,{in},{cn},{ru},{ir}
```

## 🔍 Diagnostic Details

### IP Change Verification
- Multiple IP checking services
- Tor connection verification
- Circuit establishment monitoring
- Exit node validation

### Connection Security
- Cookie authentication
- Control port verification
- Process isolation
- Circuit separation

### Error Handling
- Detailed error messages
- Progress indicators
- Status tracking
- Recovery suggestions

## 🎯 Troubleshooting Tips

1. **IP Not Changing**
   - Wait for circuit establishment
   - Check exit node configuration
   - Verify SOCKS proxy settings
   - Ensure Tor is running

2. **Authentication Issues**
   - Verify cookie file exists
   - Check file permissions
   - Restart Tor service
   - Regenerate authentication

3. **Connection Problems**
   - Check firewall settings
   - Verify ports are open
   - Test network connectivity
   - Check Tor status

## 💡 Best Practices

- Run as Administrator for full functionality
- Allow time for circuit establishment
- Monitor resource usage
- Keep Tor updated
- Regular configuration checks

## 🔧 Maintenance

- Regular GeoIP updates
- Configuration backups
- Log monitoring
- Performance optimization
---

## 📜 License

This project is **open-source** and licensed under the **MIT License**.
Feel free to **use, modify, and distribute** it.

---

## 🤝 Contributing

Want to improve **TorNetManager**?
🔹 **Fork the repo** & submit PRs
🔹 **Suggest new features** in the Issues tab
🔹 **Report bugs** & provide feedback

### Development Guidelines
1. Follow PowerShell best practices
2. Maintain consistent error handling
3. Update documentation
4. Add tests for new features

---

## 📢 Contact

For **questions, issues, or suggestions**, reach out via:
📧 **Email:** `your.email@example.com`
🐙 **GitHub:** [GitHub Profile](https://github.com/yourusername)

---

## 🚀 Getting Started

Ready to enhance your network privacy and control? Start using **TorNetManager** today!

1. Clone the repository
2. Run the setup script
3. Launch NetworkManager.ps1
4. Choose your desired network operation

## ⭐ Support the Project

- Star the repository
- Share with others
- Report issues
- Contribute code
- Provide feedback

---

Remember to use this tool responsibly and in compliance with all applicable laws and regulations.
