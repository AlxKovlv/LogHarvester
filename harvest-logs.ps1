<#
.SYNOPSIS
    Generic Log Harvester for Distributed Systems

.DESCRIPTION
    Reads a configuration file (config.json) to collect log files from local and remote machines.
    Supports dry run, grouping logs by machine, and snapshotting config for traceability.

.NOTES
    Exit Codes:
        1 - Config not found
        2 - Invalid HarvestMode
        3 - Invalid FileNameFormat
        4 - Unreachable machines
        5 - Missing log files
        0 - Success
#>

# ------------------ Configuration ------------------

$script:ConfigPath = ".\config.json"
$script:MissingFiles = @()
$script:UnreachableMachines = @()
$script:IgnoreMachines = @()
$script:IsDryRun = $false

function LoadConfiguration {
    if (-Not (Test-Path $ConfigPath)) {
        Write-Host "[ERROR] Configuration file not found at $ConfigPath" -ForegroundColor Red
        exit 1
    }

    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

    # Validate HarvestMode
    $validModes = @("HarvestOnce")
    if ($validModes -notcontains $config.HarvestMode) {
        Write-Host "[ERROR] Unsupported HarvestMode '$($config.HarvestMode)' detected." -ForegroundColor Red
        exit 2
    }

    # Validate FileNameFormat
    $validFormats = @("Original", "Prefix")
    if ($validFormats -notcontains $config.FileNameFormat) {
        Write-Host "[ERROR] Unsupported FileNameFormat: $($config.FileNameFormat). Use 'Original' or 'Prefix'." -ForegroundColor Red
        exit 3
    }

    # Set global dry run flag
    if ($config.PSObject.Properties.Name -contains "DryRun" -and $config.DryRun -eq $true) {
        $script:IsDryRun = $true
        Write-Host "[INFO] Dry Run mode is ENABLED. No files will be copied." -ForegroundColor Yellow
    }

    return $config
}

function Show-IgnoredMachines {
    param ($config)

    if ($config.PSObject.Properties.Name -contains "IgnoreMachines") {
        $script:IgnoreMachines = $config.IgnoreMachines
        if ($IgnoreMachines.Count -gt 0) {
            Write-Host "[INFO] Machines marked to ignore:" -ForegroundColor DarkYellow
            $IgnoreMachines | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkYellow }
            Write-Host ""
        }
    }
}

# ------------------ Connectivity Check ------------------

function Test-MachineConnectivity {
    param ($machines)

    Write-Host "`n[*] Verifying remote machine connectivity..." -ForegroundColor DarkCyan
    foreach ($machine in $machines) {
        if ($IgnoreMachines -contains $machine.MachineID) {
            Write-Host "    -> Skipping machine '$($machine.MachineID)' (Ignored)" -ForegroundColor DarkYellow
            continue
        }

        if (-Not $machine.IsLocal) {
            $machineID = $machine.MachineID
            $machineName = $machine.MachineName

            Write-Host "    -> Pinging '$machineID ($machineName)'..." -ForegroundColor DarkGray
            $pingResult = Test-Connection -ComputerName $machineName -Count 1 -Quiet

            if (-Not $pingResult) {
                Write-Host "    [ERROR] Machine '$machineID ($machineName)' is unreachable!" -ForegroundColor Red
                $script:UnreachableMachines += "$machineID ($machineName)"
            } else {
                Write-Host "    [OK] Machine '$machineID ($machineName)' is reachable." -ForegroundColor DarkGreen
            }
        }
    }

    if ($UnreachableMachines.Count -gt 0) {
        Write-Host "`n[ERROR] Aborting harvest. Unreachable machines detected:" -ForegroundColor Red
        $UnreachableMachines | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
        exit 4
    }
}

# ------------------ File Helpers ------------------

function EnsureDirectoryExists {
    param ($path)
    if ($IsDryRun) { return }
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

function Copy-LogFile {
    param (
        [string]$sourcePath,
        [string]$destinationFile
    )
    if ($IsDryRun) {
        Write-Host "       DRY RUN: Would copy to: $destinationFile" -ForegroundColor Yellow
        return
    }

    try {
        Copy-Item -Path $sourcePath -Destination $destinationFile -Force
        Write-Host "       Status: Copied" -ForegroundColor DarkGreen
    } catch {
        Write-Host "       [ERROR] Failed to copy: $_" -ForegroundColor Red
    }
}

# ------------------ Main Harvesting ------------------

function HarvestLogs {
    param ($machines, $config, $timestampFolder, $fileNameFormat)

    foreach ($machine in $machines) {
        if ($IgnoreMachines -contains $machine.MachineID) {
            Write-Host "[!] Skipping Machine '$($machine.MachineID)' - Ignored by config" -ForegroundColor DarkYellow
            continue
        }

        $machineID = $machine.MachineID
        $machineName = $machine.MachineName
        $logs = $machine.Logs

        Write-Host "[+] Processing Machine: $machineID ($machineName)" -ForegroundColor DarkCyan

        foreach ($logItem in $logs) {
            $componentName = $logItem.ComponentName
            $sourcePath = $logItem.SourcePath

            if (-Not (Test-Path $sourcePath)) {
                Write-Host "    -> WARNING: Log file not found: $sourcePath" -ForegroundColor Red
                $script:MissingFiles += $sourcePath
                continue
            }

            $originalFileName = Split-Path $sourcePath -Leaf
            $destinationFileName = switch ($fileNameFormat) {
                "Original" { $originalFileName }
                "Prefix"   { "$machineID-$originalFileName" }
            }

            $finalDestinationFolder = $timestampFolder
            if ($config.GroupLogsByMachine -eq $true) {
                $finalDestinationFolder = Join-Path -Path $timestampFolder -ChildPath $machineID
                EnsureDirectoryExists $finalDestinationFolder
            }

            $destinationFile = Join-Path -Path $finalDestinationFolder -ChildPath $destinationFileName

            Write-Host "    -> Harvesting Component: $componentName" -ForegroundColor DarkGray
            Write-Host "       Source: $sourcePath" -ForegroundColor DarkGray
            Write-Host "       Target: $destinationFileName" -ForegroundColor DarkGray

            Copy-LogFile -sourcePath $sourcePath -destinationFile $destinationFile
            Write-Host ""
        }
    }
}

# ------------------ Main Flow ------------------

$config = LoadConfiguration
Show-IgnoredMachines -config $config

$machinesSorted = $config.Machines | Sort-Object MachineID
Test-MachineConnectivity -machines $machinesSorted

Start-Sleep -Seconds 1
$destinationRoot = $config.DestinationRoot
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$timestampFolder = Join-Path -Path $destinationRoot -ChildPath $timestamp
EnsureDirectoryExists $timestampFolder

if (-not $IsDryRun) {
    $logFileName = "ExecutionLog_$timestamp.txt"
    $logFilePath = Join-Path -Path $timestampFolder -ChildPath $logFileName
    Start-Transcript -Path $logFilePath | Out-Null
}

if ($config.PSObject.Properties.Name -contains "IncludeConfigSnapshot" -and $config.IncludeConfigSnapshot -eq $true -and -not $IsDryRun) {
    $snapshotPath = Join-Path -Path $timestampFolder -ChildPath "config_snapshot.json"
    Copy-Item -Path $ConfigPath -Destination $snapshotPath -Force
}

Write-Host "`nDestination folder: $timestampFolder" -ForegroundColor DarkGray

HarvestLogs -machines $machinesSorted -config $config -timestampFolder $timestampFolder -fileNameFormat $config.FileNameFormat

# ------------------ Summary ------------------

if ($IsDryRun) {
    Write-Host "[DRY RUN] No files were actually copied. This was a simulation only." -ForegroundColor Yellow
    if ($MissingFiles.Count -gt 0) {
        Write-Host "[DRY RUN] These files were reported as missing (simulated):" -ForegroundColor Yellow
        $MissingFiles | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    }
} else {
    if ($MissingFiles.Count -gt 0) {
        Write-Host "[WARNING] Missing files detected:" -ForegroundColor Yellow
        $MissingFiles | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
        if (-not $IsDryRun) { Stop-Transcript | Out-Null }
        if ($config.AutoOpenFolder -eq $true) {Invoke-Item -Path $timestampFolder}
        exit 5
    } else {
        Write-Host "[INFO] All log files were harvested successfully!" -ForegroundColor DarkGreen
    }

    Stop-Transcript | Out-Null
    if ($config.AutoOpenFolder -eq $true) {
        Invoke-Item -Path $timestampFolder
    }
}

exit 0
