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
✅ **View Network Details** – Get **local & public IP, MAC address, and gateway**  
✅ **Change MAC Address** – Generate and apply a **random MAC**  
✅ **Renew Local IP** – Reset DHCP IP settings for a **fresh IP allocation**  
✅ **Tor IP Changer** – **Automate Tor circuit switching** to obtain a new **public IP**  
✅ **Firewall & Security Check** – Configure Windows **Firewall to allow Tor**  
✅ **Network Discovery** – Scan **active devices on the local network**  
✅ **Port Scanner** – Scan common **open ports** on target IPs  
✅ **Router Manager** – Restart your **router remotely** (if supported)  
✅ **Tor Process Management** – Ensure **only one Tor instance is running**  

---

## 📂 Folder Structure
```
TorNetManager/
│── NetworkManager.ps1     # Main PowerShell script
│── README.md              # Documentation
│── LICENSE                # License information
│── config/
│   ├── torrc              # Tor configuration file (auto-generated)
│── scripts/
│   ├── utilities.ps1       # Helper functions
│   ├── setup.ps1           # Installation script
│── docs/
│   ├── user_guide.md       # User documentation
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
ControlPort 9051
CookieAuthentication 1
CookieAuthFile C:\Users\yourusername\AppData\Roaming\tor\control_auth_cookie
MaxCircuitDirtiness 10
```
If `torrc` is missing, the script will create it automatically.

### 🔥 **Ensuring Firewall Rules**
The script verifies if **Tor's ControlPort (9051)** is allowed through **Windows Firewall** before adding a rule. If not running as **Administrator**, firewall rules cannot be modified.

---

## 🛡️ Security & Permissions
- **Run PowerShell as Administrator** to modify firewall settings  
- **Ensure Tor is installed** & properly configured for authentication  
- **Use responsibly** for privacy & security research  

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

---

## 📢 Contact
For **questions, issues, or suggestions**, reach out via:  
📧 **Email:** `your.email@example.com`  
🐙 **GitHub:** [GitHub Profile](https://github.com/yourusername)  

---

## 🚀 Ready to take control of your network & privacy? Start using **TorNetManager** today!

