# Resolve script path reliably (Fallback for Right-Click execution)
$currentScriptPath = $PSCommandPath
if ([string]::IsNullOrEmpty($currentScriptPath)) { 
    # Note: $MyInvocation is a built-in PowerShell automatic variable.
    $currentScriptPath = $MyInvocation.MyCommand.Path 
}
$currentScriptDir = Split-Path -Parent $currentScriptPath

# Auto-elevate to Administrator (Required for starting/stopping services)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    # -STA is required to prevent Windows Forms (Task Tray) from crashing
    $elevateArgs = "-STA -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$currentScriptPath`""
    Start-Process powershell.exe -Verb RunAs -ArgumentList $elevateArgs
    exit
}

# Load required assemblies for GUI
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# Configuration
$serviceName = "llama-server"
$logDir = Join-Path $currentScriptDir "logs"
$logFilePath = Join-Path $logDir "llama-service.out.log"
$iconFilePath = Join-Path $currentScriptDir "icon.ico"
$logSnapshotDir = Join-Path ([System.IO.Path]::GetTempPath()) "llama-server-tray"

# Create NotifyIcon (System Tray Icon)
$trayIcon = New-Object System.Windows.Forms.NotifyIcon

# Use custom icon if exists, otherwise use default system application icon
if (Test-Path $iconFilePath) {
    $trayIcon.Icon = New-Object System.Drawing.Icon($iconFilePath)
} else {
    # Fallback to standard Application icon instead of PowerShell's
    $trayIcon.Icon = [System.Drawing.SystemIcons]::Application
}
$trayIcon.Visible = $true

# Function to update menu states
function Update-Menu {
    $svcStatus = Get-Service $serviceName -ErrorAction SilentlyContinue
    
    if ($null -eq $svcStatus) {
        $trayIcon.Text = "Service Not Found: $serviceName"
        $btnStart.Enabled = $false
        $btnStop.Enabled = $false
        return
    }
    
    $trayIcon.Text = "llama-server: $($svcStatus.Status)"
    $btnStart.Enabled = ($svcStatus.Status -ne "Running")
    $btnStop.Enabled = ($svcStatus.Status -eq "Running")
}

function Open-LogSnapshot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath
    )

    if (-not (Test-Path $logSnapshotDir)) {
        New-Item -Path $logSnapshotDir -ItemType Directory -Force > $null
    }

    try {
        Get-ChildItem -Path $logSnapshotDir -Filter "llama-service-*.log" -ErrorAction Stop |
            Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-1) } |
            ForEach-Object {
                try {
                    Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop
                } catch {
                    Write-Warning "Failed to remove old log snapshot '$($_.FullName)': $($_.Exception.Message)"
                }
            }
    } catch {
        Write-Warning "Failed to enumerate old log snapshots: $($_.Exception.Message)"
    }

    $snapshotPath = Join-Path $logSnapshotDir ("llama-service-{0:yyyyMMdd-HHmmssfff}.log" -f (Get-Date))
    $sourceStream = $null
    $snapshotStream = $null

    try {
        $sourceStream = [System.IO.File]::Open($SourcePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $snapshotStream = [System.IO.File]::Open($snapshotPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
        $sourceStream.CopyTo($snapshotStream)
    } finally {
        if ($null -ne $snapshotStream) {
            $snapshotStream.Dispose()
        }

        if ($null -ne $sourceStream) {
            $sourceStream.Dispose()
        }
    }

    if (-not (Test-Path $snapshotPath)) {
        throw "Log snapshot could not be created."
    }

    Start-Process notepad.exe "`"$snapshotPath`""
}

# Context Menu Initialization
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

$btnStart = $contextMenu.Items.Add("Start Server", $null, { 
    Start-Service $serviceName
    Update-Menu
})

$btnStop = $contextMenu.Items.Add("Stop Server", $null, { 
    Stop-Service $serviceName
    Update-Menu
})

$contextMenu.Items.Add("-") > $null

$btnLog = $contextMenu.Items.Add("Show Log (Notepad)", $null, { 
    if (Test-Path $logFilePath) {
        try {
            Open-LogSnapshot -SourcePath $logFilePath
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Unable to open the log snapshot.`n`n$($_.Exception.Message)", "Open Log Failed", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show("Log file not found. The server may not have been started yet.", "File Not Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    }
})

$contextMenu.Items.Add("-") > $null

$btnExit = $contextMenu.Items.Add("Quit", $null, { 
    # Stop the service before quitting the manager
    Stop-Service $serviceName -Force -ErrorAction SilentlyContinue
    $trayIcon.Visible = $false
    [System.Windows.Forms.Application]::Exit()
})

$trayIcon.ContextMenuStrip = $contextMenu

# Update menu on icon click
$trayIcon.Add_Click({ Update-Menu })

# Start Application Loop
Update-Menu
$appContext = New-Object System.Windows.Forms.ApplicationContext
[System.Windows.Forms.Application]::Run($appContext)
