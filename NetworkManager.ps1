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
            $this.PublicIP = $this.GetCurrentIP()
            if (-not $this.PublicIP) {
                $this.PublicIP = "Unknown"
            }
        } catch {
            $this.PublicIP = "Unknown"
        }
    }

[string] GetCurrentIP() {
    try {
        Write-Host "📡 Setting up Tor SOCKS proxy connection..." -ForegroundColor Yellow
        
        # Define multiple IP check endpoints with increasing timeouts
        $attempts = @(
            @{
                Url = "https://api.ipify.org"
                Timeout = 10
            },
            @{
                Url = "https://icanhazip.com"
                Timeout = 15
            },
            @{
                Url = "https://ident.me"
                Timeout = 20
            }
        )

        foreach ($attempt in $attempts) {
            try {
                Write-Host "🔍 Checking IP via $($attempt.Url)..." -ForegroundColor Yellow
                
                $result = & curl.exe --socks5-hostname "127.0.0.1:9050" `
                                   --silent `
                                   --connect-timeout $attempt.Timeout `
                                   --max-time $attempt.Timeout `
                                   --retry 2 `
                                   --retry-delay 1 `
                                   $attempt.Url 2>$null

                if ($result -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$") {
                    # Verify it's actually a Tor exit node
                    $verifyTor = & curl.exe --socks5-hostname "127.0.0.1:9050" `
                                          --silent `
                                          --max-time 10 `
                                          "https://check.torproject.org" 2>$null
                    
                    if ($verifyTor -match "Congratulations\. This browser is configured to use Tor") {
                        Write-Host "✅ Successfully retrieved IP through Tor" -ForegroundColor Green
                        return $result.Trim()
                    }
                }
            }
            catch {
                Write-Host "⚠️ Failed with $($attempt.Url), trying next..." -ForegroundColor Yellow
                continue
            }
        }

        # Last resort - try with extended timeout
        try {
            Write-Host "🔄 Trying last resort check..." -ForegroundColor Yellow
            $result = & curl.exe --socks5-hostname "127.0.0.1:9050" `
                               --silent `
                               --connect-timeout 30 `
                               --max-time 30 `
                               --retry 3 `
                               "https://check.torproject.org/api/ip" 2>$null

            if ($result) {
                $ipData = $result | ConvertFrom-Json
                if ($ipData.IsTor -eq $true) {
                    Write-Host "✅ Successfully retrieved IP through Tor API" -ForegroundColor Green
                    return $ipData.IP
                }
            }
        }
        catch {
            Write-Host "❌ Last resort check failed" -ForegroundColor Red
        }

        Write-Host "❌ All IP check methods failed" -ForegroundColor Red
        return $null
    }
    catch {
        Write-Host "❌ Error during IP check: $_" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
        return $null
    }
}

    [void] RenewLocalIP() {
        Write-Host "`n🔹 Renewing Local IP..."
        ipconfig /release
        Start-Sleep -Seconds 3
        ipconfig /renew
        Write-Host "✅ Local IP Address Renewed!"
    }

    [bool] VerifyTorProxy() {
        Write-Host "`n🔹 Verifying Tor SOCKS Proxy..." -ForegroundColor Yellow
        
        try {
            # Check if SOCKS port is open
            $result = Test-NetConnection -ComputerName 127.0.0.1 -Port 9050 -WarningAction SilentlyContinue
            if (-not $result.TcpTestSucceeded) {
                Write-Host "❌ Tor SOCKS proxy port not accessible" -ForegroundColor Red
                return $false
            }
            Write-Host "✅ SOCKS proxy port is open" -ForegroundColor Green

            # Test Tor connectivity
            $result = & curl.exe --socks5-hostname "127.0.0.1:9050" `
                               --silent `
                               --max-time 30 `
                               --url "https://check.torproject.org" 2>$null

            if ($result -match "Congratulations\. This browser is configured to use Tor") {
                Write-Host "✅ Tor connection verified" -ForegroundColor Green
                return $true
            } else {
                Write-Host "❌ Not properly connected to Tor network" -ForegroundColor Red
                return $false
            }
        }
        catch {
            Write-Host "❌ Error verifying Tor proxy: $_" -ForegroundColor Red
            return $false
        }
    }

    [void] ChangePublicIPViaTor() {
        Write-Host "`n🔹 Requesting a New Tor IP..."
    
        # First verify Tor proxy is working
        if (-not $this.VerifyTorProxy()) {
            Write-Host "❌ Please ensure Tor is properly configured and running" -ForegroundColor Red
            return
        }

        # Get initial IP
        $initialIP = $this.GetCurrentIP()
        if (-not $initialIP) {
            Write-Host "❌ Failed to get initial IP" -ForegroundColor Red
            return
        }
        Write-Host "📍 Initial IP: $initialIP" -ForegroundColor Cyan

        # Setup Tor control connection with timeout
        try {
            Write-Host "🔄 Opening Tor control connection..." -ForegroundColor Yellow
            $controller = New-Object System.Net.Sockets.TcpClient
            $connectResult = $controller.BeginConnect("127.0.0.1", 9051, $null, $null)
            $waitResult = $connectResult.AsyncWaitHandle.WaitOne(5000, $true)
        
            if (-not $waitResult) {
                Write-Host "❌ Connection timeout" -ForegroundColor Red
                return
            }
            
            $stream = $controller.GetStream()
            $stream.ReadTimeout = 5000  # 5 second timeout for reads
            $stream.WriteTimeout = 5000  # 5 second timeout for writes
            $writer = New-Object System.IO.StreamWriter($stream)
            $reader = New-Object System.IO.StreamReader($stream)
            $writer.AutoFlush = $true

            # Read authentication cookie
            $cookieAuthPath = "C:\Users\Pradeep\AppData\Roaming\tor\control_auth_cookie"
            Write-Host "🔐 Reading authentication cookie..." -ForegroundColor Yellow
            $authCookie = [BitConverter]::ToString([System.IO.File]::ReadAllBytes($cookieAuthPath)) -replace '-'
        
            # Authenticate
            Write-Host "🔒 Authenticating with Tor control port..." -ForegroundColor Yellow
            $writer.WriteLine("AUTHENTICATE $authCookie")
            $response = $reader.ReadLine()
            
            if ($response -ne "250 OK") {
                Write-Host "❌ Authentication failed: $response" -ForegroundColor Red
                return
            }
            Write-Host "✅ Authentication successful" -ForegroundColor Green

            # Request new circuit
            Write-Host "`n🔄 Requesting new circuit..." -ForegroundColor Yellow
            $writer.WriteLine("SIGNAL NEWNYM")
            $response = $reader.ReadLine()
            
            if ($response -ne "250 OK") {
                Write-Host "❌ Failed to request new circuit: $response" -ForegroundColor Red
                return
            }

            # Wait for circuit establishment
            Write-Host "⏳ Establishing new circuit..." -ForegroundColor Yellow
            $totalSeconds = 10
            for ($second = 1; $second -le $totalSeconds; $second++) {
                $percent = [math]::Round(($second / $totalSeconds) * 100)
                $progressBar = "[" + ("=" * [math]::Round($percent/5)) + (" " * (20 - [math]::Round($percent/5))) + "]"
                Write-Host "`r$progressBar $percent% Complete" -NoNewline -ForegroundColor Cyan
                Start-Sleep -Seconds 1
            }
            Write-Host "`r✓ Circuit establishment complete                        " -ForegroundColor Green

            # Verify IP change
            Write-Host "`n📡 Verifying IP change..." -ForegroundColor Yellow
            $newIP = $this.GetCurrentIP()
            if ($newIP) {
                Write-Host "📍 New IP: $newIP" -ForegroundColor Cyan
                if ($newIP -ne $initialIP) {
                    Write-Host "✅ IP change successful!" -ForegroundColor Green
                    $this.PublicIP = $newIP
                }
                else {
                    Write-Host "⚠️ IP remained the same" -ForegroundColor Yellow
                }
            }
            else {
                Write-Host "❌ Failed to verify new IP" -ForegroundColor Red
            }

            # Cleanup
            $writer.Close()
            $reader.Close()
            $stream.Close()
            $controller.Close()
        }
        catch {
            Write-Host "`n❌ Error during IP change: $_" -ForegroundColor Red
        }
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
