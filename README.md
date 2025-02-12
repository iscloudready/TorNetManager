# 🚀 TorNetManager

*A PowerShell-based Network Management Tool with Tor Integration*

![TorNetManager](https://img.shields.io/badge/PowerShell-Network--Tool-blue.svg)
![Tor](https://img.shields.io/badge/Tor-Privacy-purple.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## 📜 Description

**TorNetManager** is an advanced PowerShell-based network management tool that provides comprehensive network control and anonymity features. It combines network management capabilities with Tor integration for enhanced privacy and security.

---

## 🔹 Key Features

### Network Management
- 🌐 View detailed network information (MAC, IP, Gateway)
- 🔄 Change MAC address with random generation
- 📡 Local IP renewal through DHCP
- 🛜 Router management capabilities
- 🔍 Network device discovery

### Tor Integration
- 🧅 Automated Tor circuit management
- 🌍 Dynamic IP rotation through Tor
- ✨ Verified IP changes with multiple fallbacks
- 🛡️ Tor connection verification
- 🔒 Secure cookie authentication

### Security Features
- 🔥 Automatic firewall configuration
- 🔍 Port scanning capabilities
- 🛠️ Process management
- 📊 Network monitoring

---

## 📋 Requirements

- Windows 10/11
- PowerShell 5.1 or higher
- Tor Browser Bundle or Tor Expert Bundle
- Administrator privileges (for some features)

---

## 🛠️ Installation

1. **Clone the Repository**
   ```powershell
   git clone https://github.com/yourusername/TorNetManager.git
   cd TorNetManager
   ```

2. **Install Tor**
   - Download Tor Expert Bundle
   - Extract to `C:\DevOps\tor\`
   - Verify installation path: `C:\DevOps\tor\tor\tor.exe`

3. **Configure Tor**
   The script will automatically:
   - Create required directories
   - Generate torrc configuration
   - Set up authentication
   - Configure firewall rules

---

## 🎯 Usage

### Running the Tool
```powershell
.\TorNetManager.ps1
```

### Main Menu Options
1. 🌐 Get Network Settings
2. 🔄 Change MAC Address
3. 📡 Renew Local IP
4. 🛠️ Install & Configure Tor
5. 🌍 Change Public IP via Tor
6. 🔄 Restart Router
7. 🔍 Discover Devices
8. 📊 Scan Open Ports

### Tor IP Changing Feature
```powershell
# Automatically changes your IP through Tor
# Verifies the change through multiple services:
- api.ipify.org
- icanhazip.com
- ident.me
- check.torproject.org
```

---

## ⚙️ Configuration

### Tor Configuration
```ini
# Automatic torrc generation with secure defaults
ControlPort 9051
CookieAuthentication 1
CookieAuthFile C:\Users\[username]\AppData\Roaming\tor\control_auth_cookie
MaxCircuitDirtiness 10
NewCircuitPeriod 10
EnforceDistinctSubnets 1
```

### Network Configuration
- Automatic adapter detection
- DHCP configuration management
- Firewall rule management
- Process monitoring

---

## 🛡️ Security Features

### IP Verification
- Multiple IP checking services
- Tor connection verification
- Circuit creation monitoring
- Connection security checks

### Authentication
- Cookie-based authentication
- Secure control port access
- Process isolation
- Firewall protection

---

## 📝 Logging & Feedback

The tool provides detailed feedback with:
- ✅ Success indicators
- ⚠️ Warning messages
- ❌ Error notifications
- 📊 Progress tracking

---

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

---

## 📜 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## ⚠️ Disclaimer

This tool is for educational and research purposes only. Users are responsible for compliance with applicable laws and regulations.

---

## 🆘 Support

For issues, questions, or suggestions:
- Create an issue on GitHub
- Submit a pull request
- Contact the maintainers

---

## 🎉 Acknowledgments

- The Tor Project
- PowerShell Community
- Contributors & Testers
