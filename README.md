# 🪵 Generic Log Harvester

A simple and customizable PowerShell-based tool for harvesting log files from local and remote machines.

## 🚀 Features

- Collects logs from multiple machines based on a JSON config file
- Supports local and remote (network share) file collection
- Automatic timestamped folder organization
- Dry run support for testing
- Optional grouping of logs by machine
- Optional snapshot of config at the time of harvesting
- Clear and color-coded terminal output with `run-harvest.bat`
- Auto-open folder with results (configurable)

## 🧰 Requirements

- Windows environment
- PowerShell 5.1 or later
- Access to remote network shares if applicable

## 📁 Repository Structure

```
/LogHarvester/
│
├── config.json            # Configuration file defining machines and log paths
├── harvest-logs.ps1       # Main PowerShell script
├── run-harvest.bat        # User-friendly wrapper for launching the script
└── README.md              # This file
```

## ⚙️ Configuration

The behavior is defined in `config.json`. Here's an example:

```json
{
  "DestinationRoot": "C:\\Path\\To\\CollectedLogs\\",
  "HarvestMode": "HarvestOnce",
  "FileNameFormat": "Prefix",
  "AutoOpenFolder": true,
  "GroupLogsByMachine": true,
  "IncludeConfigSnapshot": true,
  "DryRun": false,
  "IgnoreMachines": [],
  "Machines": [
    {
      "MachineID": "LocalMachine",
      "MachineName": "localhost",
      "IsLocal": true,
      "Logs": [
        {
          "ComponentName": "ServiceA",
          "SourcePath": "C:\\Logs\\ServiceA\\log.txt"
        }
      ]
    },
    {
      "MachineID": "Remote1",
      "MachineName": "192.168.1.10",
      "IsLocal": false,
      "Logs": [
        {
          "ComponentName": "RemoteService",
          "SourcePath": "\\\\192.168.1.10\\SharedLogs\\RemoteService\\log.txt"
        }
      ]
    }
  ]
}
```

### Parameters Explained

| Key                    | Description |
|------------------------|-------------|
| `DestinationRoot`      | Where collected logs will be stored |
| `HarvestMode`          | Currently supports only `"HarvestOnce"` |
| `FileNameFormat`       | `"Original"` or `"Prefix"` to add MachineID to filename |
| `AutoOpenFolder`       | Opens destination folder in Explorer after harvesting |
| `GroupLogsByMachine`   | Organizes files into folders per machine |
| `IncludeConfigSnapshot`| Saves a copy of `config.json` in the log folder |
| `DryRun`               | Simulates actions without copying files |
| `IgnoreMachines`       | List of machine IDs to skip |
| `Machines`             | Array of machine objects containing logs to collect |

## ▶️ Usage

1. Customize `config.json` to match your setup.
2. Double-click `run-harvest.bat` or run it from the terminal:
   ```sh
   .\run-harvest.bat
   ```

Logs will be saved under a timestamped folder in the `DestinationRoot`.

## ✅ Exit Codes

| Code | Meaning                               |
|------|----------------------------------------|
| 0    | Success                                |
| 1    | Config file not found                  |
| 2    | Invalid `HarvestMode`                 |
| 3    | Invalid `FileNameFormat`              |
| 4    | One or more remote machines unreachable|
| 5    | One or more log files missing          |

