Clear-Host

# --------------------- CLASS: Network Manager ---------------------
class NetworkManager {
    [string]$AdapterName
    [string]$MacAddress
    [string]$LocalIP
    [string]$PublicIP
    [string]$Gateway

    NetworkManager() {
        $networkAdapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.InterfaceDescription -notmatch "Virtual|Loopback" }
        if ($networkAdapter) {
            $this.AdapterName = $networkAdapter.Name
            $this.MacAddress = $networkAdapter.MacAddress
            $this.Gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Select-Object -ExpandProperty NextHop)
            
            $localIPObj = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceIndex -eq $networkAdapter.ifIndex -and $_.PrefixOrigin -eq "Dhcp" }
            if ($localIPObj) {
                $this.LocalIP = $localIPObj.IPAddress
            } else {
                $this.LocalIP = "⚠️ No DHCP IP Assigned"
            }
        } else {
            $this.AdapterName = "⚠️ No Active Network Adapter Found"
            $this.MacAddress = "⚠️ No MAC Available"
            $this.LocalIP = "⚠️ No Local IP"
            $this.Gateway = "⚠️ No Gateway Found"
        }

        # Fetch public IP
        try {
            $this.PublicIP = (Invoke-WebRequest -Uri "http://checkip.amazonaws.com" -UseBasicParsing).Content.Trim()
        } catch {
            $this.PublicIP = "⚠️ Failed to Retrieve Public IP"
        }
    }

    [void] ShowNetworkSettings() {
        Write-Host "`n🌐 Adapter Name: $($this.AdapterName)"
        Write-Host "🔀 MAC Address: $($this.MacAddress)"
        Write-Host "📌 Local IP: $($this.LocalIP)"
        Write-Host "📡 Public IP: $($this.PublicIP)"
        Write-Host "🛜 Gateway (Router IP): $($this.Gateway)"
    }
}

# --------------------- CLASS: MAC Address Changer ---------------------
class MACManager {
    [void] ChangeMAC() {
        Write-Host "`n🔹 Generating a New MAC Address..."
        $randomMAC = -join ((48, 50, 52, 54, 56, 58) | Get-Random) + ":" + ((1..5) | ForEach-Object { "{0:X2}" -f (Get-Random -Minimum 0 -Maximum 256) }) -replace " ", ":"

        Write-Host "🔄 New MAC Address: $randomMAC"
        $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
        Set-NetAdapter -Name $adapter.Name -MacAddress $randomMAC
        Restart-NetAdapter -Name $adapter.Name
        Write-Host "✅ MAC Address Changed!"
    }
}

# --------------------- CLASS: IP Address Manager ---------------------
class IPManager {
    [string]$PublicIP

    IPManager() {
        try {
            $this.PublicIP = (Invoke-WebRequest -Uri "http://checkip.amazonaws.com" -UseBasicParsing).Content.Trim()
        } catch {
            $this.PublicIP = "Unknown"
        }
    }

    [void] RenewLocalIP() {
        Write-Host "`n🔹 Renewing Local IP..."
        ipconfig /release
        Start-Sleep -Seconds 3
        ipconfig /renew
        Write-Host "✅ Local IP Address Renewed!"
    }

    [void] ChangePublicIPViaTor() {
        Write-Host "`n🔹 Requesting a New Tor IP..."
    
        # Check if Tor is running
        $torRunning = Get-Process -Name "tor" -ErrorAction SilentlyContinue
        if (-not $torRunning) {
            Write-Host "❌ Tor is not running. Please start Tor first."
            return
        }

        # Check if Tor's ControlPort 9051 is accessible
        $connectionTest = Test-NetConnection -ComputerName 127.0.0.1 -Port 9051
        if (-not $connectionTest.TcpTestSucceeded) {
            Write-Host "❌ Tor ControlPort 9051 is not accessible. Ensure Tor is configured properly."
            return
        }

        # Read the authentication cookie
        $cookieAuthPath = "C:\Users\Pradeep\AppData\Roaming\tor\control_auth_cookie"
        if (-not (Test-Path $cookieAuthPath)) {
            Write-Host "❌ Authentication cookie missing. Please restart Tor."
            return
        }
    
        $authCookie = [BitConverter]::ToString([System.IO.File]::ReadAllBytes($cookieAuthPath)) -replace '-'
    
        if ([string]::IsNullOrWhiteSpace($authCookie)) {
            Write-Host "❌ Authentication cookie is empty or invalid. Restart Tor and try again."
            return
        }

        $retryCount = 0
        $maxRetries = 3
        $oldPublicIP = (Invoke-WebRequest -Uri "http://checkip.amazonaws.com" -UseBasicParsing).Content.Trim()

        while ($retryCount -lt $maxRetries) {
            try {
                # Establish connection to Tor's control port
                $controller = New-Object System.Net.Sockets.TcpClient
                $controller.Connect("127.0.0.1", 9051)
                $stream = $controller.GetStream()
                $writer = New-Object System.IO.StreamWriter($stream)
                $writer.AutoFlush = $true
                $reader = New-Object System.IO.StreamReader($stream)

                # Authenticate with Tor
                $writer.WriteLine("AUTHENTICATE $authCookie")
                Start-Sleep -Seconds 2
                $response = $reader.ReadLine()

                if ($response -notmatch "250 OK") {
                    Write-Host "❌ Authentication failed: $response"
                    return
                }

                # Request a new Tor circuit
                Write-Host "🔄 Requesting a new Tor circuit..."
                $writer.WriteLine("SIGNAL NEWNYM")
                Start-Sleep -Seconds 5

                # Close the connection properly
                $writer.Close()
                $reader.Close()
                $stream.Close()
                $controller.Close()

                # Wait for the new circuit to establish
                Start-Sleep -Seconds 10

                # Retrieve the new public IP
                $newPublicIP = (Invoke-WebRequest -Uri "http://checkip.amazonaws.com" -UseBasicParsing).Content.Trim()

                if ($newPublicIP -ne $oldPublicIP -and $newPublicIP -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$") {
                    Write-Host "✅ New Public IP: $newPublicIP"
                    $this.PublicIP = $newPublicIP
                    return  # Exit loop if IP has changed
                } else {
                    Write-Host "❌ Public IP did not change. Retrying ($($retryCount + 1)/$maxRetries)..."
                    Start-Sleep -Seconds 5
                }
            } catch {
                Write-Host "❌ Failed to communicate with Tor. Error: $_"
            }

            $retryCount++
        }

        Write-Host "❌ Maximum retries reached. Public IP did not change. Try restarting Tor."
    }

}

# --------------------- CLASS: Router Manager ---------------------
class RouterManager {
    [void] RestartRouter([string]$routerIP, [string]$username, [string]$password) {
        Write-Host "`n🔹 Restarting Router at $routerIP..."
        $restartUrl = "http://$routerIP/reboot.cgi"
        Invoke-WebRequest -Uri $restartUrl -Credential (New-Object System.Management.Automation.PSCredential ($username, (ConvertTo-SecureString $password -AsPlainText -Force))) -Method POST
        Write-Host "✅ Router Restarted!"
    }
}

# --------------------- CLASS: Network Discovery ---------------------
class NetworkDiscovery {
    [array]$deviceList = @()

    [void] DiscoverDevices() {
        Write-Host "`n🔹 Scanning Network Devices..."
        
        $arpTable = arp -a | ForEach-Object { $_ -match "(\d+\.\d+\.\d+\.\d+)\s+([a-f0-9-]+)" | Out-Null; if ($matches) { $matches[1], $matches[2] } }
        
        if ($arpTable.Count -eq 0) {
            Write-Host "⚠️ No devices found on the network."
            return
        }

        $this.deviceList = @()

        Write-Host "`n📡 Active Network Devices:"
        Write-Host "---------------------------------------------------------"
        Write-Host "IP Address        MAC Address        Device Name      Vendor   OS"
        Write-Host "---------------------------------------------------------"

        for ($i = 0; $i -lt $arpTable.Count; $i += 2) {
            $ip = $arpTable[$i]
            $mac = $arpTable[$i + 1]

            # Ignore broadcast, virtual, and empty MACs
            if ($mac -match "ff-ff-ff-ff-ff-ff" -or $mac -match "00-00-00-00-00-00") { continue }

            # Try to resolve hostname
            $hostname = try {
                (Resolve-DnsName -Name $ip -ErrorAction Stop).NameHost
            } catch {
                "Unknown"
            }

            # Get MAC Vendor
            $vendor = try {
                (Invoke-WebRequest -Uri "https://api.macvendors.com/$mac" -UseBasicParsing).Content.Trim()
            } catch {
                "Unknown Vendor"
            }

            # Guess OS based on TTL values
            $ttl = (Test-Connection -ComputerName $ip -Count 1 -ErrorAction SilentlyContinue).ResponseTime
            if ($ttl -lt 65) {
                $os = "Linux/Unix"
            } elseif ($ttl -lt 129) {
                $os = "Windows"
            } else {
                $os = "Unknown"
            }

            Write-Host "$ip`t$mac`t$hostname`t$vendor`t$os"

            # Store in array for future use
            $this.deviceList += [PSCustomObject]@{
                IP          = $ip
                MAC         = $mac
                Hostname    = $hostname
                Vendor      = $vendor
                OS          = $os
            }
        }

        Write-Host "---------------------------------------------------------"
        Write-Host "`n✅ Devices discovered successfully!"
    }
}

class PortScanner {
    [void] ScanOpenPorts([string]$ip) {
        Write-Host "`n🔍 Scanning Ports for $ip..."
        
        if (-not ($ip -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$")) {
            Write-Host "❌ Invalid IP Address. Skipping scan."
            return
        }

        $openPorts = @()
        $commonPorts = @(22, 23, 25, 53, 80, 110, 139, 443, 445, 3389, 8080, 5900) # Add more if needed
        
        Write-Host "-------------------------------------------------"
        Write-Host "Port   | Service       | Status"
        Write-Host "-------------------------------------------------"

        foreach ($port in $commonPorts) {
            if (Test-NetConnection -ComputerName $ip -Port $port -InformationLevel Quiet) {
                $service = switch ($port) {
                    22 { "SSH" }
                    23 { "Telnet" }
                    25 { "SMTP" }
                    53 { "DNS" }
                    80 { "HTTP" }
                    110 { "POP3" }
                    139 { "NetBIOS" }
                    443 { "HTTPS" }
                    445 { "SMB" }
                    3389 { "RDP" }
                    8080 { "Web Proxy" }
                    5900 { "VNC" }
                    default { "Unknown" }
                }
                Write-Host "$port`t| $service`t| Open"
                $openPorts += "$port ($service)"
            }
        }

        Write-Host "-------------------------------------------------"
        
        if ($openPorts.Count -eq 0) {
            Write-Host "🚫 No open ports found on $ip"
        } else {
            Write-Host "✅ Open Ports: $($openPorts -join ', ')"
        }
    }
}

# --------------------- CLASS: TorManager ---------------------
class TorManager {
    [string]$TorPath
    [string]$TorConfigPath

    TorManager() {
        $this.TorPath = "C:\DevOps\tor\tor\tor.exe"
        $this.TorConfigPath = "$env:APPDATA\tor\torrc"
    }

    [void] CheckAndStartTor() {
        Write-Host "`n🔹 Checking Tor Installation..."

        # Check if Tor is installed
        if (-Not (Test-Path $this.TorPath)) {
            Write-Host "❌ Tor is not installed at expected location: $($this.TorPath)"
            Write-Host "⚠️ Please verify the path and update it in the script."
            return
        }
        Write-Host "✅ Tor is installed at: $($this.TorPath)"

        # Ensure Tor is configured properly
        $this.ConfigureTor()

        # Check if Tor process is running
        $torProcess = Get-Process -Name "tor" -ErrorAction SilentlyContinue
        if ($torProcess) {
            Write-Host "✅ Tor is already running on process ID: $($torProcess.Id)"
        } else {
            Write-Host "⚠️ Tor is not running. Attempting to start..."
            Start-Process -FilePath $this.TorPath -NoNewWindow
            Start-Sleep -Seconds 5

            # Recheck after starting
            $torProcess = Get-Process -Name "tor" -ErrorAction SilentlyContinue
            if ($torProcess) {
                Write-Host "✅ Tor started successfully!"
            } else {
                Write-Host "❌ Failed to start Tor. Please start manually."
                return
            }
        }

        # Verify ControlPort
        $this.VerifyControlPort()
    }

    [void] ConfigureTor() {
        Write-Host "`n🔹 Checking Tor Configuration..."
    
        # Define torrc path
        if (-Not (Test-Path $this.TorConfigPath)) {
            Write-Host "⚠️ Tor configuration file not found. Creating default config..."
            New-Item -ItemType File -Path $this.TorConfigPath -Force | Out-Null
        }

        # Read current config (if file exists)
        $torConfig = @()
        if (Test-Path $this.TorConfigPath) {
            $torConfig = Get-Content $this.TorConfigPath -ErrorAction SilentlyContinue
        }

        # Required settings
        $requiredSettings = @(
            "ControlPort 9051",
            "CookieAuthentication 1",
            "CookieAuthFile C:\Users\Pradeep\AppData\Roaming\tor\control_auth_cookie",
            "MaxCircuitDirtiness 10"
        )

        $configUpdated = $false

        # Check and update missing settings
        foreach ($setting in $requiredSettings) {
            if (-not ($torConfig -match [regex]::Escape($setting))) {
                Write-Host "⚠️ Missing setting: $setting. Adding it to torrc..."
                Add-Content -Path $this.TorConfigPath -Value $setting
                $configUpdated = $true
            }
        }

        # If changes were made, update torrc
        if ($configUpdated) {
            Write-Host "✅ Tor configuration updated!"
        } else {
            Write-Host "✅ Tor configuration is already correct. No changes needed."
        }

        # Ensure only one instance of Tor is running
        $this.KillDuplicateTorInstances()

        # Restart Tor to apply changes
        Write-Host "`n🔹 Restarting Tor to apply changes..."
        Stop-Process -Name "tor" -Force -ErrorAction SilentlyContinue
        Start-Process -FilePath $this.TorPath -NoNewWindow
        Start-Sleep -Seconds 5
        Write-Host "✅ Tor restarted successfully!"

        # Allow ControlPort through Windows Firewall
        $this.ConfigureFirewall()
    }

    [void] VerifyControlPort() {
        Write-Host "`n🔹 Verifying if Tor's ControlPort is accessible..."
        $connectionTest = Test-NetConnection -ComputerName 127.0.0.1 -Port 9051
        if ($connectionTest.TcpTestSucceeded) {
            Write-Host "✅ Tor is properly configured and ControlPort 9051 is accessible!"
        } else {
            Write-Host "❌ Tor's ControlPort is still not accessible. Check firewall and Tor logs."
        }
    }

    [void] ConfigureFirewall() {
        Write-Host "`n🔹 Configuring Windows Firewall for Tor..."
    
        # Check if the script has admin privileges
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        if (-Not $isAdmin) {
            Write-Host "❌ Firewall rule cannot be added. Please run PowerShell as Administrator."
            return
        }

        # Check if the rule already exists
        if (-Not (Get-NetFirewallRule -DisplayName "Allow Tor ControlPort" -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -DisplayName "Allow Tor ControlPort" -Direction Inbound -Protocol TCP -LocalPort 9051 -Action Allow
            Write-Host "✅ Firewall rule added!"
        } else {
            Write-Host "✅ Firewall rule already exists."
        }
    }

    [void] ConfigureTorFirewall() {
        Write-Host "`n🔹 Configuring Windows Firewall for Tor..."

        # Check if the firewall rule already exists
        $existingRule = Get-NetFirewallRule -DisplayName "Allow Tor ControlPort" -ErrorAction SilentlyContinue

        if ($existingRule) {
            Write-Host "✅ Firewall rule already exists. No changes needed."
        } else {
            try {
                # Add firewall rule only if it's missing
                New-NetFirewallRule -DisplayName "Allow Tor ControlPort" -Direction Inbound -Protocol TCP -LocalPort 9051 -Action Allow
                Write-Host "✅ Firewall rule added successfully!"
            } catch {
                Write-Host "❌ Firewall rule cannot be added. Please run PowerShell as Administrator."
            }
        }
    }

    [void] KillDuplicateTorInstances() {
        Write-Host "`n🔹 Checking for duplicate Tor processes..."
        $torProcesses = Get-Process -Name "tor" -ErrorAction SilentlyContinue
        if ($torProcesses.Count -gt 1) {
            Write-Host "⚠️ Multiple Tor processes detected. Stopping duplicates..."
            $torProcesses | Select-Object -Skip 1 | Stop-Process -Force
            Write-Host "✅ Duplicate Tor instances terminated."
        }
    }

}

# --------------------- INITIALIZING OBJECTS ---------------------
$networkManager = [NetworkManager]::new()
$macManager = [MACManager]::new()
$ipManager = [IPManager]::new()
$routerManager = [RouterManager]::new()
$networkDiscovery = [NetworkDiscovery]::new()
$portScanner = [PortScanner]::new()
$torManager = [TorManager]::new()

do {
    Clear-Host
    Write-Host "🔵 Choose an Option: "
    Write-Host "1️⃣ Get Network Settings"
    Write-Host "2️⃣ Change MAC Address"
    Write-Host "3️⃣ Renew Local IP"
    Write-Host "4️⃣ Install & Configure Tor"
    Write-Host "5️⃣ Change Public IP via Tor"
    Write-Host "6️⃣ Restart Router"
    Write-Host "7️⃣ Discover Devices"
    Write-Host "8️⃣ Scan Open Ports"
    Write-Host "9️⃣ Exit"
    $choice = Read-Host "Enter your choice"

    switch ($choice) {
        "1" { $networkManager.ShowNetworkSettings() }
        "2" { $macManager.ChangeMAC() }
        "3" { $ipManager.RenewLocalIP() }
        "4" { $torManager.CheckAndStartTor() }
        "5" { $ipManager.ChangePublicIPViaTor() }
        "6" { 
            $routerIP = Read-Host "Enter Router IP"
            $username = Read-Host "Enter Router Username"
            $password = Read-Host "Enter Router Password"
            $routerManager.RestartRouter($routerIP, $username, $password)
        }
        "7" { $networkDiscovery.DiscoverDevices() }
        "8" {
            $targetIP = Read-Host "Enter target IP for port scan (Leave blank for local IP)"
    
            if ([string]::IsNullOrWhiteSpace($targetIP)) {
                # Auto-detect Local IP
                $targetIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceIndex -eq (Get-NetAdapter | Where-Object { $_.Status -eq "Up" }).ifIndex }).IPAddress
                Write-Host "🔍 No target IP provided. Scanning local IP: $targetIP"
            }

            if ($targetIP -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$") {
                $portScanner.ScanOpenPorts($targetIP)
            } else {
                Write-Host "❌ Invalid IP Address. Please try again."
            }
        }

        "9" { Write-Host "👋 Exiting..."; exit }
        default { Write-Host "❌ Invalid Choice! Try Again." }
    }
    
    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
} while ($true)
