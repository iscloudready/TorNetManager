# Add at the beginning of the script
try {
    Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    public class CookieUtil {
        [DllImport("wininet.dll", SetLastError = true)]
        public static extern bool InternetGetCookieEx(string url, string cookieName, System.Text.StringBuilder cookieData, ref int size, int dwFlags, IntPtr reserved);
        
        [DllImport("wininet.dll", SetLastError = true)]
        public static extern bool InternetSetCookie(string lpszUrlName, string lpszCookieName, string lpszCookieData);
    }
"@ -ErrorAction SilentlyContinue
} catch {}

# Configuration class to store all settings
class BrowserCleanupConfig {
    static [hashtable] $Settings = @{
            ManualCleanupSteps = @{
            Chrome = @(
                "1. Type chrome://net-internals/#dns in Chrome"
                "2. Click 'Clear host cache'"
                "3. Go to chrome://net-internals/#sockets"
                "4. Click 'Flush socket pools'"
                "5. Try opening in an Incognito window"
                "6. Go to chrome://settings/clearBrowserData"
                "7. Select 'All time' for time range"
                "8. Check all options"
                "9. Click 'Clear data'"
            )
        }
        RestartPrompt = "Would you like to restart your computer now? (Y/N)"

        Browsers = @{
            Chrome = @{
                UserDataPath = "$env:LOCALAPPDATA\Google\Chrome\User Data"
                ExecutablePaths = @(
                    "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
                    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
                )
                CachePaths = @(
                    "Cache"
                    "Code Cache"
                    "Cache\Cache_Data"
                    "Network"
                    "Service Worker"
                    "Storage"
                    "Session Storage"
                    "Local Storage"
                    "IndexedDB"
                    "GPUCache"
                    "Application Cache"
                )
                DomainSpecificPaths = @{
                    ServiceWorkers = "Service Worker\CacheStorage"
                    IndexedDB = "IndexedDB"
                    LocalStorage = "Local Storage\leveldb"
                    Cookies = "Network\Cookies"
                }
            }
        }
        WaitTimes = @{
            BrowserShutdown = 2
            ProcessCheck = 1
        }
    }
}

# Interfaces and Base Classes
class IBrowserCleaner {
    [void] ClearCache([string]$domain, [bool]$cleanAll) { throw "Not Implemented" }
    [void] ClearCookies([string]$domain) { throw "Not Implemented" }
    [void] StopBrowser() { throw "Not Implemented" }
    [void] StartBrowser() { throw "Not Implemented" }
}

class INetworkCleaner {
    [void] ResetNetworkStack() { throw "Not Implemented" }
    [void] ClearDNSCache() { throw "Not Implemented" }
    [void] ResetProxy() { throw "Not Implemented" }
}

# Concrete Implementations
class ChromeCleaner : IBrowserCleaner {
    hidden [string] $tempCookiesPath
    hidden [bool] $cookieUtilInitialized

    ChromeCleaner() {
        $this.cookieUtilInitialized = Initialize-CookieUtil
        if (-not $this.cookieUtilInitialized) {
            [Logger]::Log("ChromeCleaner initialized without cookie functionality", "Warning")
        }
    }

    [void] ClearDomainSpecificData($profile, $domain) {
        [Logger]::Log("Cleaning domain-specific data for $domain in profile: $($profile.Name)")
        
        $config = [BrowserCleanupConfig]::Settings.Browsers.Chrome
        $domainPaths = $config.DomainSpecificPaths

        try {
            # Clean Service Workers for domain
            $swPath = Join-Path $profile.FullName $domainPaths.ServiceWorkers
            if (Test-Path $swPath) {
                Get-ChildItem $swPath -Recurse | 
                Where-Object { $_.Name -like "*$domain*" } | 
                Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            }

            # Clean IndexedDB for domain
            $idbPath = Join-Path $profile.FullName $domainPaths.IndexedDB
            if (Test-Path $idbPath) {
                Get-ChildItem $idbPath -Recurse | 
                Where-Object { $_.Name -like "*$domain*" } | 
                Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            }

            # Clean Local Storage for domain
            $lsPath = Join-Path $profile.FullName $domainPaths.LocalStorage
            if (Test-Path $lsPath) {
                Get-ChildItem $lsPath -Recurse | 
                Where-Object { $_.Name -like "*$domain*" } | 
                Remove-Item -Force -ErrorAction SilentlyContinue
            }

            # Clean domain cookies
            $cookiesPath = Join-Path $profile.FullName $domainPaths.Cookies
            if (Test-Path $cookiesPath) {
                try {
                    # Define the temp path in the local scope
                    $this.tempCookiesPath = Join-Path $env:TEMP "Cookies_temp_$($profile.Name)"
                    Copy-Item -Path $cookiesPath -Destination $this.tempCookiesPath -Force
                    
                    # Using Windows API for cookie deletion
                    $result = [CookieUtil]::InternetSetCookie("https://$domain", $null, $null)
                    if ($result) {
                        [Logger]::Log("Successfully deleted cookies for $domain in profile: $($profile.Name)")
                    }
                } catch {
                    [Logger]::Log("Failed to clean cookies for $domain in profile: $($profile.Name)", "Warning")
                } finally {
                    if ($this.tempCookiesPath -and (Test-Path $this.tempCookiesPath)) {
                        Remove-Item $this.tempCookiesPath -Force -ErrorAction SilentlyContinue
                        $this.tempCookiesPath = $null
                    }
                }
            }

        } catch {
            [Logger]::Log("Error cleaning domain-specific data: $_", "Error")
            throw
        }
    }

    [void] ClearFullProfile($profile) {
        [Logger]::Log("Performing full cleanup for profile: $($profile.Name)")
        
        $config = [BrowserCleanupConfig]::Settings.Browsers.Chrome
        
        try {
            foreach ($cachePath in $config.CachePaths) {
                $fullPath = Join-Path $profile.FullName $cachePath
                if (Test-Path $fullPath) {
                    [Logger]::Log("Clearing $cachePath")
                    Remove-Item -Path "$fullPath\*" -Recurse -Force -ErrorAction SilentlyContinue
                }
            }

            # Reset profile preferences
            $prefsPath = Join-Path $profile.FullName "Preferences"
            if (Test-Path $prefsPath) {
                $backupPath = "$prefsPath.backup"
                Rename-Item -Path $prefsPath -NewName $backupPath -Force -ErrorAction SilentlyContinue
                [Logger]::Log("Reset preferences for profile: $($profile.Name)")
            }

            # Clear all cookies
            $cookiesPath = Join-Path $profile.FullName $config.DomainSpecificPaths.Cookies
            if (Test-Path $cookiesPath) {
                Remove-Item -Path $cookiesPath -Force -ErrorAction SilentlyContinue
                [Logger]::Log("Cleared all cookies for profile: $($profile.Name)")
            }

        } catch {
            [Logger]::Log("Error during full profile cleanup: $_", "Error")
            throw
        }
    }

    [void] StopBrowser() {
        try {
            $processes = Get-Process chrome -ErrorAction SilentlyContinue
            if ($processes) {
                $processes | Stop-Process -Force
                Start-Sleep -Seconds ([int][BrowserCleanupConfig]::Settings.WaitTimes.BrowserShutdown)
            }
        } catch {
            [Logger]::Log("Error stopping Chrome: $_", "Warning")
        }
    }

    [void] StartBrowser() {
        try {
            $config = [BrowserCleanupConfig]::Settings.Browsers.Chrome
            foreach ($path in $config.ExecutablePaths) {
                if (Test-Path $path) {
                    Start-Process $path
                    break
                }
            }
        } catch {
            [Logger]::Log("Error starting Chrome: $_", "Warning")
        }
    }

        [void] ClearCache([string]$domain, [bool]$cleanAll) {
        $chromeUserData = [BrowserCleanupConfig]::Settings.Browsers.Chrome.UserDataPath
        if (Test-Path $chromeUserData) {
            $profiles = Get-ChildItem $chromeUserData -Directory | 
                       Where-Object { $_.Name -match '^Profile \d+$|^Default$' }
            
            foreach ($profile in $profiles) {
                if ($cleanAll) {
                    $this.ClearFullProfile($profile)
                } else {
                    $this.ClearDomainSpecificData($profile, $domain)
                }
            }
        }
    }

    [void] ClearCookies([string]$domain) {
        if (-not $this.cookieUtilInitialized) {
            [Logger]::Log("Cookie functionality not available", "Warning")
            return
        }
        try {
            $result = [CookieUtil]::InternetSetCookie("https://$domain", $null, $null)
            if ($result) {
                [Logger]::Log("Successfully deleted cookies for domain: $domain")
            }
        } catch {
            [Logger]::Log("Failed to delete cookies using Windows API", "Warning")
        }
    }
}

class WindowsNetworkCleaner : INetworkCleaner {
    [void] ClearDNSCache() {
        Start-Process -FilePath "ipconfig" -ArgumentList "/flushdns" -Wait -NoNewWindow
    }

        [void] ResetProxy() {
        try {
            Start-Process -FilePath "netsh" -ArgumentList "winhttp reset proxy" -Wait -NoNewWindow
            [Logger]::Log("Reset WinHTTP Proxy successfully")
        } catch {
            [Logger]::Log("Failed to reset proxy: $_", "Error")
        }
    }

    # Enhance existing methods
    [void] ResetNetworkStack() {
        try {
            Start-Process -FilePath "netsh" -ArgumentList "winsock reset" -Wait -NoNewWindow
            Start-Process -FilePath "netsh" -ArgumentList "int ip reset" -Wait -NoNewWindow
            Start-Process -FilePath "ipconfig" -ArgumentList "/release" -Wait -NoNewWindow
            Start-Process -FilePath "ipconfig" -ArgumentList "/renew" -Wait -NoNewWindow
            [Logger]::Log("Network stack reset successfully")
        } catch {
            [Logger]::Log("Failed to reset network stack: $_", "Error")
        }
    }
}

# Configuration Manager
class CleanupConfig {
    [string]$Domain
    [bool]$CleanAll
    [bool]$RestartRequired
    [array]$BrowsersToClean

    CleanupConfig() {
        $this.Domain = ""
        $this.CleanAll = $true
        $this.RestartRequired = $false
        $this.BrowsersToClean = @("chrome", "edge", "firefox")
    }

    CleanupConfig([string]$domain) {
        $this.Domain = $domain
        $this.CleanAll = [string]::IsNullOrEmpty($domain)
        $this.RestartRequired = $false
        $this.BrowsersToClean = @("chrome", "edge", "firefox")
    }
}

# Main Cleanup Orchestrator
class BrowserCleanupOrchestrator {
    [CleanupConfig]$Config
    [array]$BrowserCleaners
    [INetworkCleaner]$NetworkCleaner

    BrowserCleanupOrchestrator([CleanupConfig]$config) {
        $this.Config = $config
        $this.InitializeCleaners()
    }

    [void] InitializeCleaners() {
        $this.BrowserCleaners = @(
            [ChromeCleaner]::new()
            # Add other browser cleaners
        )
        $this.NetworkCleaner = [WindowsNetworkCleaner]::new()
    }

    [void] ExecuteCleanup() {
        # Network cleanup
        $this.NetworkCleaner.ResetNetworkStack()
        $this.NetworkCleaner.ClearDNSCache()

        # Browser cleanup
        foreach($cleaner in $this.BrowserCleaners) {
            $cleaner.StopBrowser()
            $cleaner.ClearCache($this.Config.Domain, $this.Config.CleanAll)
            $cleaner.ClearCookies($this.Config.Domain)
            $cleaner.StartBrowser()
        }
    }

    [void] PromptForRestart() {
        [Logger]::Log("`n" + [BrowserCleanupConfig]::Settings.RestartPrompt)
        $restart = Read-Host
        if ($restart -eq 'Y' -or $restart -eq 'y') {
            [Logger]::Log("Initiating system restart...")
            Restart-Computer -Force
        }
    }
}

# Logger Utility
class Logger {
    static [void] Log([string]$message) {
        [Logger]::Log($message, "Info")
    }

    static [void] Log([string]$message, [string]$level) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$timestamp] [$level] $message"
    }
}

# Parameters for command-line usage
param(
    [Parameter(Mandatory=$false)]
    [string]$domain,
    [Parameter(Mandatory=$false)]
    [switch]$noPrompt
)

# Main Script
try {
    clear-host
    [Logger]::Log("Starting browser cleanup process")
    
    $proceed = $false
    
    # If no domain provided via command line, and noPrompt is not set
    if ([string]::IsNullOrEmpty($domain) -and -not $noPrompt) {
        [Logger]::Log("Do you want to:", "Info")
        [Logger]::Log("1. Clean specific domain", "Info")
        [Logger]::Log("2. Clean all browser data", "Info")
        
        $choice = Read-Host "Enter your choice (1 or 2)"
        
        if ($choice -eq "1") {
            $domain = Read-Host "Enter the domain name (e.g., usinfoway.com)"
        }
    }

    # Handle different scenarios
    if ([string]::IsNullOrEmpty($domain)) {
        # Full cleanup scenario
        if (-not $noPrompt) {
            [Logger]::Log("WARNING: This will clean ALL browser data.", "Warning")
            [Logger]::Log("This action will:", "Info")
            [Logger]::Log("1. Clear all browser caches", "Info")
            [Logger]::Log("2. Delete all cookies", "Info")
            [Logger]::Log("3. Reset browser preferences", "Info")
            [Logger]::Log("4. Clear network settings", "Info")
            
            $response = Read-Host "Do you want to continue with full cleanup? (Y/N)"
            $proceed = $response -eq 'Y' -or $response -eq 'y'
        } else {
            $proceed = $true
        }
        
        if ($proceed) {
            $config = [CleanupConfig]::new()
        }
    } else {
        # Domain-specific cleanup
        if (-not $noPrompt) {
            [Logger]::Log("Domain specified: $domain", "Info")
            [Logger]::Log("This will clean all data related to: $domain", "Info")
            
            $response = Read-Host "Do you want to continue with domain-specific cleanup? (Y/N)"
            $proceed = $response -eq 'Y' -or $response -eq 'y'
        } else {
            $proceed = $true
        }
        
        if ($proceed) {
            $config = [CleanupConfig]::new($domain)
        }
    }

    if ($proceed) {
        $orchestrator = [BrowserCleanupOrchestrator]::new($config)
        $orchestrator.ExecuteCleanup()

        [Logger]::Log("Cleanup completed successfully")

        # Display manual cleanup steps
        [Logger]::Log("`nIf you still experience issues in Chrome:", "Info")
        foreach($step in [BrowserCleanupConfig]::Settings.ManualCleanupSteps.Chrome) {
            [Logger]::Log($step, "Info")
        }

        # Prompt for restart if not in no-prompt mode
        if (-not $noPrompt) {
            $orchestrator.PromptForRestart()
        }
    } else {
        [Logger]::Log("Operation cancelled by user", "Info")
    }

} catch {
    [Logger]::Log("An error occurred: $_", "Error")
}
