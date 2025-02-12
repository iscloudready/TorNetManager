class TorTroubleshooter {
    [string]$TorPath
    [string]$TorConfigPath
    [string]$TorDataDir
    [string]$AuthCookiePath

    TorTroubleshooter() {
        # Initialize paths
        $this.TorPath = "C:\DevOps\tor\tor\tor.exe"
        $this.TorConfigPath = "$env:APPDATA\tor\torrc"
        $this.TorDataDir = "$env:APPDATA\tor"
        $this.AuthCookiePath = "$($this.TorDataDir)\control_auth_cookie"
    }

    [void] RunFullDiagnostics() {
        Write-Host "`n🔍 Starting Full Tor Diagnostics...`n" -ForegroundColor Cyan
        
        $this.CheckTorInstallation()
        $this.VerifyTorConfiguration()
        $this.CheckTorProcess()
        $this.TestControlPort()
        $this.VerifyAuthentication()
        $this.CheckNetworkConnectivity()
        
        Write-Host "`n✅ Diagnostics Complete!`n" -ForegroundColor Green
    }

    [bool] CheckTorInstallation() {
        Write-Host "🔹 Checking Tor Installation..." -ForegroundColor Yellow
        
        if (-not (Test-Path $this.TorPath)) {
            Write-Host "❌ Tor executable not found at: $($this.TorPath)" -ForegroundColor Red
            Write-Host "   Please verify Tor installation path" -ForegroundColor Red
            return $false
        }

        # Check version
        try {
            $torVersion = & $this.TorPath --version
            Write-Host "✅ Tor version: $torVersion" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "❌ Failed to get Tor version: $_" -ForegroundColor Red
            return $false
        }
    }

    [void] VerifyTorConfiguration() {
        Write-Host "`n🔹 Verifying Tor Configuration..." -ForegroundColor Yellow

        # Check if config file exists
        if (-not (Test-Path $this.TorConfigPath)) {
            Write-Host "⚠️ Tor config file not found. Creating new one..." -ForegroundColor Yellow
            $this.CreateDefaultConfig()
        }

        # Read and verify config content
        $config = Get-Content $this.TorConfigPath -ErrorAction SilentlyContinue
        $requiredSettings = @(
            "ControlPort 9051",
            "CookieAuthentication 1",
            "DataDirectory",
            "MaxCircuitDirtiness"
        )

        foreach ($setting in $requiredSettings) {
            if (-not ($config -match $setting)) {
                Write-Host "❌ Missing required setting: $setting" -ForegroundColor Red
            }
        }

        Write-Host "📄 Current Tor Configuration:" -ForegroundColor Cyan
        $config | ForEach-Object { Write-Host "   $_" }
    }

    [void] CreateDefaultConfig() {
        $defaultConfig = @"
# Default Tor Configuration
ControlPort 9051
CookieAuthentication 1
DataDirectory $($this.TorDataDir)
MaxCircuitDirtiness 10
"@
        
        New-Item -ItemType Directory -Force -Path $this.TorDataDir | Out-Null
        Set-Content -Path $this.TorConfigPath -Value $defaultConfig
        Write-Host "✅ Created default Tor configuration" -ForegroundColor Green
    }

    [bool] CheckTorProcess() {
        Write-Host "`n🔹 Checking Tor Process..." -ForegroundColor Yellow
        
        $torProcess = Get-Process -Name "tor" -ErrorAction SilentlyContinue
        
        if ($torProcess) {
            Write-Host "✅ Tor is running" -ForegroundColor Green
            Write-Host "   Process ID: $($torProcess.Id)" -ForegroundColor Green
            Write-Host "   CPU Usage: $($torProcess.CPU)" -ForegroundColor Green
            Write-Host "   Memory Usage: $([math]::Round($torProcess.WorkingSet / 1MB, 2)) MB" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "❌ Tor is not running" -ForegroundColor Red
            return $false
        }
    }

    [bool] TestControlPort() {
        Write-Host "`n🔹 Testing Tor Control Port..." -ForegroundColor Yellow
        
        $result = Test-NetConnection -ComputerName 127.0.0.1 -Port 9051 -WarningAction SilentlyContinue
        
        if ($result.TcpTestSucceeded) {
            Write-Host "✅ Control Port (9051) is accessible" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "❌ Control Port (9051) is not accessible" -ForegroundColor Red
            Write-Host "   This might be due to:" -ForegroundColor Yellow
            Write-Host "   - Tor not running" -ForegroundColor Yellow
            Write-Host "   - Firewall blocking the port" -ForegroundColor Yellow
            Write-Host "   - Incorrect ControlPort setting" -ForegroundColor Yellow
            return $false
        }
    }

    [bool] VerifyAuthentication() {
        Write-Host "`n🔹 Verifying Authentication..." -ForegroundColor Yellow
        
        if (-not (Test-Path $this.AuthCookiePath)) {
            Write-Host "❌ Authentication cookie not found at: $($this.AuthCookiePath)" -ForegroundColor Red
            return $false
        }

        try {
            $cookieContent = [System.IO.File]::ReadAllBytes($this.AuthCookiePath)
            if ($cookieContent.Length -eq 0) {
                Write-Host "❌ Authentication cookie is empty" -ForegroundColor Red
                return $false
            }
            
            $authCookie = [BitConverter]::ToString($cookieContent) -replace '-'
            Write-Host "✅ Authentication cookie is valid" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "❌ Failed to read authentication cookie: $_" -ForegroundColor Red
            return $false
        }
    }

[string] GetCurrentIP() {
    try {
        Write-Host "📡 Setting up Tor SOCKS proxy connection..." -ForegroundColor Yellow
        
        # Force using curl with Tor SOCKS proxy
        try {
            Write-Host "🔍 Checking IP through Tor..." -ForegroundColor Yellow
            
            # Explicitly use curl with socks5h to force DNS resolution through Tor
            $result = & curl.exe --socks5-hostname "127.0.0.1:9050" `
                               --silent `
                               --max-time 30 `
                               --retry 3 `
                               --retry-delay 2 `
                               --url "https://check.torproject.org/api/ip" 2>$null

            if ($result) {
                $ipData = $result | ConvertFrom-Json
                if ($ipData.IsTor -eq $true) {
                    Write-Host "✅ Connected through Tor successfully" -ForegroundColor Green
                    return $ipData.IP
                } else {
                    Write-Host "⚠️ Connection not using Tor" -ForegroundColor Yellow
                    return $null
                }
            }
        }
        catch {
            Write-Host "⚠️ Primary check failed, trying alternate method..." -ForegroundColor Yellow
            
            # Fallback to direct check with check.torproject.org
            try {
                $result = & curl.exe --socks5-hostname "127.0.0.1:9050" `
                                   --silent `
                                   --max-time 30 `
                                   --url "https://check.torproject.org" 2>$null
                
                if ($result -match "Congratulations\. This browser is configured to use Tor") {
                    $ip = & curl.exe --socks5-hostname "127.0.0.1:9050" `
                                   --silent `
                                   "https://api.ipify.org"
                    if ($ip -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$") {
                        Write-Host "✅ Verified Tor connection" -ForegroundColor Green
                        return $ip
                    }
                } else {
                    Write-Host "⚠️ Not connected through Tor network" -ForegroundColor Yellow
                    return $null
                }
            }
            catch {
                Write-Host "❌ Failed to verify Tor connection" -ForegroundColor Red
                return $null
            }
        }

        Write-Host "❌ All IP check methods failed" -ForegroundColor Red
        return $null
    }
    catch {
        Write-Host "❌ Error during IP check: $_" -ForegroundColor Red
        return $null
    }
}

[void] TestIPChange() {
    Write-Host "`n🔹 Testing Tor IP Change Functionality..." -ForegroundColor Yellow

    if (-not $this.VerifyTorProxy()) {
        Write-Host "❌ Please check Tor configuration and try again" -ForegroundColor Red
        return
    }

    # First get current IP
    Write-Host "📡 Fetching initial IP..." -ForegroundColor Cyan
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
        Write-Host "🔐 Reading authentication cookie..." -ForegroundColor Yellow
        $authCookie = [BitConverter]::ToString([System.IO.File]::ReadAllBytes("$($this.TorDataDir)\control_auth_cookie")) -replace '-'
    
        # Authenticate
        Write-Host "🔒 Authenticating with Tor control port..." -ForegroundColor Yellow
        $writer.WriteLine("AUTHENTICATE $authCookie")
        try {
            $response = $reader.ReadLine()
            if ($response -ne "250 OK") {
                Write-Host "❌ Authentication failed: $response" -ForegroundColor Red
                return
            }
            Write-Host "✅ Authentication successful" -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Authentication timed out" -ForegroundColor Red
            return
        }

        # Test circuit creation
        Write-Host "`n🔄 Testing circuit creation..." -ForegroundColor Yellow
    
        for ($i = 1; $i -le 3; $i++) {
            Write-Host "`n📍 Attempt $i of 3:" -ForegroundColor Cyan
        
            # Get circuit info with progress indicator
            Write-Host "📊 Checking current circuits..." -ForegroundColor Yellow
            $circuits = @()
            $writer.WriteLine("GETINFO circuit-status")
            $spinChars = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
            $spinIdx = 0
            $timeoutTimer = [System.Diagnostics.Stopwatch]::StartNew()

            while ($timeoutTimer.ElapsedMilliseconds -lt 5000) {
                try {
                    Write-Host "`r$($spinChars[$spinIdx % $spinChars.Length]) Reading circuit info..." -NoNewline
                    $spinIdx++
                    $line = $reader.ReadLine()
                    if ($line -eq ".") { break }
                    if ($line -ne "250+circuit-status=") {
                        $circuits += $line
                    }
                }
                catch [System.IO.IOException] {
                    Write-Host "`n⚠️ Circuit status check timed out" -ForegroundColor Yellow
                    break
                }
            }
            Write-Host "`r✓ Active circuits: $($circuits.Count)           " -ForegroundColor Green

            # Request new circuit with progress bar
            Write-Host "`n🔄 Requesting new circuit..." -ForegroundColor Yellow
            $writer.WriteLine("SIGNAL NEWNYM")
            try {
                $response = $reader.ReadLine()
                if ($response -ne "250 OK") {
                    Write-Host "❌ Failed to request new circuit: $response" -ForegroundColor Red
                    continue
                }
            }
            catch {
                Write-Host "❌ New circuit request timed out" -ForegroundColor Red
                continue
            }

            # Circuit establishment progress
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
                    break
                }
                else {
                    Write-Host "⚠️ IP remained the same" -ForegroundColor Yellow
                }
            }
            else {
                Write-Host "❌ Failed to verify new IP" -ForegroundColor Red
            }

            # Cooldown between attempts
            if ($i -lt 3) {
                Write-Host "`n⏳ Cooling down before next attempt..." -ForegroundColor Yellow
                $cooldownTime = 15
                for ($j = 1; $j -le $cooldownTime; $j++) {
                    $percent = [math]::Round(($j / $cooldownTime) * 100)
                    $progressBar = "[" + ("=" * [math]::Round($percent/5)) + (" " * (20 - [math]::Round($percent/5))) + "]"
                    Write-Host "`r$progressBar $percent% Cooldown: $j/$cooldownTime seconds" -NoNewline -ForegroundColor Cyan
                    Start-Sleep -Seconds 1
                }
                Write-Host "`r✓ Cooldown complete                                        " -ForegroundColor Green
            }
        }

        # Cleanup
        $writer.Close()
        $reader.Close()
        $stream.Close()
        $controller.Close()
    }
    catch {
        Write-Host "`n❌ Error during IP change test: $_" -ForegroundColor Red
    }
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

    [void] CheckNetworkConnectivity() {
        Write-Host "`n🔹 Checking Network Connectivity..." -ForegroundColor Yellow
        
        # Test general internet connectivity
        $internetTest = Test-NetConnection -ComputerName 8.8.8.8 -Port 53 -WarningAction SilentlyContinue
        if ($internetTest.TcpTestSucceeded) {
            Write-Host "✅ Internet connectivity test passed" -ForegroundColor Green
        }
        else {
            Write-Host "❌ Internet connectivity test failed" -ForegroundColor Red
        }

        # Test Tor connectivity
        try {
            $torTest = Test-NetConnection -ComputerName "check.torproject.org" -Port 443 -WarningAction SilentlyContinue
            if ($torTest.TcpTestSucceeded) {
                Write-Host "✅ Can reach Tor Project website" -ForegroundColor Green
            }
            else {
                Write-Host "❌ Cannot reach Tor Project website" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "❌ Failed to test Tor connectivity: $_" -ForegroundColor Red
        }
    }

    [void] RestartTor() {
        Write-Host "`n🔹 Attempting to restart Tor..." -ForegroundColor Yellow
        
        # Stop existing Tor process
        Stop-Process -Name "tor" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        
        # Start new Tor process
        try {
            Start-Process -FilePath $this.TorPath -NoNewWindow
            Write-Host "✅ Tor restarted successfully" -ForegroundColor Green
            Start-Sleep -Seconds 5  # Wait for Tor to initialize
            $this.CheckTorProcess()
        }
        catch {
            Write-Host "❌ Failed to restart Tor: $_" -ForegroundColor Red
        }
    }

[bool] FixGeoIPConfiguration() {
    Write-Host "`n🔹 Fixing GeoIP Configuration..." -ForegroundColor Yellow
    
    $geoipDir = $this.TorDataDir
    $geoipFile = Join-Path $geoipDir "geoip"
    $geoip6File = Join-Path $geoipDir "geoip6"

    # Create directory if it doesn't exist
    if (-not (Test-Path $geoipDir)) {
        New-Item -ItemType Directory -Force -Path $geoipDir | Out-Null
    }

    # Updated GeoIP URLs
    $geoipUrl = "https://raw.githubusercontent.com/torproject/tor/release-0.4.8/src/config/geoip"
    $geoip6Url = "https://raw.githubusercontent.com/torproject/tor/release-0.4.8/src/config/geoip6"

    try {
        Write-Host "📥 Downloading GeoIP files..." -ForegroundColor Yellow
        
        # Download files using .NET WebClient (more reliable than Invoke-WebRequest)
        $webClient = New-Object System.Net.WebClient
        
        Write-Host "   Downloading GeoIP database..." -ForegroundColor Cyan
        $webClient.DownloadFile($geoipUrl, $geoipFile)
        
        Write-Host "   Downloading GeoIPv6 database..." -ForegroundColor Cyan
        $webClient.DownloadFile($geoip6Url, $geoip6File)

        # Verify files exist and have content
        if ((Test-Path $geoipFile) -and (Test-Path $geoip6File)) {
            $geoipSize = (Get-Item $geoipFile).Length
            $geoip6Size = (Get-Item $geoip6File).Length
            
            if ($geoipSize -gt 0 -and $geoip6Size -gt 0) {
                Write-Host "✅ GeoIP files downloaded successfully:" -ForegroundColor Green
                Write-Host "   - GeoIP database size: $([math]::Round($geoipSize/1KB, 2)) KB" -ForegroundColor Green
                Write-Host "   - GeoIPv6 database size: $([math]::Round($geoip6Size/1KB, 2)) KB" -ForegroundColor Green
                
# Update the torrcContent in FixGeoIPConfiguration method:
$torrcContent = @"
# Basic Configuration
ControlPort 9051
CookieAuthentication 1
CookieAuthFile $($this.AuthCookiePath)
DataDirectory $($this.TorDataDir)

# GeoIP Configuration
GeoIPFile $geoipFile
GeoIPv6File $geoip6File

# Force Specific Exit Nodes (one per line for clarity)
ExitNodes {fr} 
StrictNodes 1
ExcludeNodes BadExit,{in},{cn},{ru},{ir}

# Aggressive Circuit Rotation
MaxCircuitDirtiness 5
NewCircuitPeriod 5
CircuitBuildTimeout 10
LeaveStreamsUnattached 1

# SOCKS Proxy Configuration
SocksPort 9050
SocksListenAddress 127.0.0.1
SOCKSPolicy accept 127.0.0.1
SafeSocks 1

# Performance Settings
FastFirstHopPK 0
UseEntryGuards 0
OptimisticData auto
"@
                Set-Content -Path $this.TorConfigPath -Value $torrcContent
                Write-Host "✅ Tor configuration updated with GeoIP paths" -ForegroundColor Green
                return $true
            }
        }
        Write-Host "❌ GeoIP files verification failed" -ForegroundColor Red
        return $false
    }
    catch {
        Write-Host "❌ Error downloading GeoIP files: $_" -ForegroundColor Red
        
        # Fallback URL if first attempt fails
        try {
            Write-Host "`n📥 Trying alternate download source..." -ForegroundColor Yellow
            $geoipUrl = "https://gitweb.torproject.org/tor.git/plain/src/config/geoip?h=release-0.4.8"
            $geoip6Url = "https://gitweb.torproject.org/tor.git/plain/src/config/geoip6?h=release-0.4.8"
            
            # Create new WebClient instance for fallback attempt
            $newWebClient = New-Object System.Net.WebClient
            $newWebClient.DownloadFile($geoipUrl, $geoipFile)
            $newWebClient.DownloadFile($geoip6Url, $geoip6File)
            
            if ((Test-Path $geoipFile) -and (Test-Path $geoip6File)) {
                Write-Host "✅ GeoIP files downloaded successfully from alternate source" -ForegroundColor Green
                return $true
            }
        }
        catch {
            Write-Host "❌ Failed to download from alternate source" -ForegroundColor Red
        }
        return $false
    }
}

[void] EnhanceExitNodeConfiguration() {
    Write-Host "`n🔹 Enhancing Exit Node Configuration..." -ForegroundColor Yellow
    
    # First fix GeoIP configuration
    $geoipSuccess = $this.FixGeoIPConfiguration()
    if (-not $geoipSuccess) {
        Write-Host "⚠️ Failed to set up GeoIP files. Country-based routing might not work." -ForegroundColor Yellow
        $continue = Read-Host "Would you like to continue anyway? (y/n)"
        if ($continue -ne 'y') {
            return # Valid in void method as it's just exiting
        }
    }
    
    Write-Host "`n⚠️ Tor needs to be restarted for changes to take effect" -ForegroundColor Yellow
    Write-Host "⚠️ After restart, wait 30 seconds before testing IP change" -ForegroundColor Yellow
    $restart = Read-Host "Would you like to restart Tor now? (y/n)"
    if ($restart -eq 'y') {
        $this.RestartTor()
        Write-Host "`n⏳ Waiting 30 seconds for Tor to establish initial circuits..." -ForegroundColor Yellow
        $totalSeconds = 30
        for ($second = 1; $second -le $totalSeconds; $second++) {
            $percent = [math]::Round(($second / $totalSeconds) * 100)
            $progressBar = "[" + ("=" * [math]::Round($percent/5)) + (" " * (20 - [math]::Round($percent/5))) + "]"
            Write-Host "`r$progressBar $percent% Complete: $second/$totalSeconds seconds" -NoNewline -ForegroundColor Cyan
            Start-Sleep -Seconds 1
        }
        Write-Host "`r✅ Tor initialization complete                                        " -ForegroundColor Green
    }
}
}

# Update the menu section
# Create troubleshooter instance
$torTroubleshooter = [TorTroubleshooter]::new()

# Show menu
do {
    Clear-Host
    Write-Host "🔵 Tor Troubleshooter Menu:" -ForegroundColor Cyan
    Write-Host "1️⃣ Run Full Diagnostics"
    Write-Host "2️⃣ Check Tor Installation"
    Write-Host "3️⃣ Verify Tor Configuration"
    Write-Host "4️⃣ Check Tor Process"
    Write-Host "5️⃣ Test Control Port"
    Write-Host "6️⃣ Verify Authentication"
    Write-Host "7️⃣ Check Network Connectivity"
    Write-Host "8️⃣ Test IP Change Functionality"
    Write-Host "9️⃣ Restart Tor"
    Write-Host "🔟 Enhance Exit Node Configuration"
    Write-Host "1️⃣1️⃣ Exit"
    
    $choice = Read-Host "`nEnter your choice"
    
    switch ($choice) {
        "1" { $torTroubleshooter.RunFullDiagnostics() }
        "2" { $torTroubleshooter.CheckTorInstallation() }
        "3" { $torTroubleshooter.VerifyTorConfiguration() }
        "4" { $torTroubleshooter.CheckTorProcess() }
        "5" { $torTroubleshooter.TestControlPort() }
        "6" { $torTroubleshooter.VerifyAuthentication() }
        "7" { $torTroubleshooter.CheckNetworkConnectivity() }
        "8" { $torTroubleshooter.TestIPChange() }
        "9" { $torTroubleshooter.RestartTor() }
        "10" { $torTroubleshooter.EnhanceExitNodeConfiguration() }
        "11" { Write-Host "`n👋 Exiting..."; exit }
        default { Write-Host "`n❌ Invalid choice! Please try again." -ForegroundColor Red }
    }
    
    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
} while ($true)
