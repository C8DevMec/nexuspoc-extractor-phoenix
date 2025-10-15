# PI Data Fetcher

A PowerShell script that retrieves data from OSIsoft PI System using the AF SDK. Supports both real-time snapshot data and historical archived data queries.

## Prerequisites

- **OSIsoft AF SDK** installed at `C:\Program Files (x86)\PIPC\AF\PublicAssemblies\4.0\`
- **PowerShell 5.1** or higher
- **Network access** to PI Server
- **Appropriate permissions** to read PI data

## Parameters

| Parameter | Required | Description | Default |
|-----------|----------|-------------|---------|
| `TagNames` | Yes | Comma-separated list of PI tag names | - |
| `StartTime` | No* | Start time for archived data (ISO format or relative) | - |
| `EndTime` | No* | End time for archived data (ISO format or relative) | - |
| `ServerName` | No | PI Server name (uses default if not specified) | Default PI Server |

**Note:** Both `StartTime` and `EndTime` must be provided together for archived data queries.

## Usage Examples

### Snapshot Data (Current Values)

Retrieve the latest values for specified tags:
```powershell
.\Get-PIData.ps1 -TagNames "TAG001,TAG002,TAG003"
```

### Archived Data (Historical Values)

Retrieve historical data within a time range:
```powershell
# Absolute time range
.\Get-PIData.ps1 -TagNames "TAG001,TAG002" -StartTime "2025-10-01T00:00:00Z" -EndTime "2025-10-15T00:00:00Z"

# Relative time range
.\Get-PIData.ps1 -TagNames "TAG001" -StartTime "*-7d" -EndTime "*"
```

### Specify PI Server

Connect to a specific PI Server:
```powershell
.\Get-PIData.ps1 -TagNames "TAG001" -ServerName "PISERVER01"
```

## Output Format

The script returns JSON with the following structure:
```json
[
  {
    "TagName": "TAG001",
    "Value": 123.45,
    "Timestamp": "2025-10-15T10:30:00.0000000Z",
    "IsGood": true
  },
  {
    "TagName": "TAG002",
    "Value": 67.89,
    "Timestamp": "2025-10-15T10:30:00.0000000Z",
    "IsGood": true
  }
]
```

## Features

- **Dual Mode Operation**: Automatically switches between snapshot and archived data based on parameters
- **Bulk Tag Lookup**: Efficiently retrieves multiple tags in a single operation
- **Good Data Filtering**: Only returns values with `IsGood` status
- **UTC Timestamps**: All timestamps are in ISO 8601 format (UTC)
- **Error Handling**: Comprehensive error messages for troubleshooting

## Data Query Modes

### Mode 1: Snapshot Data
- Triggered when `StartTime` and `EndTime` are **not** provided
- Returns the most recent value for each tag
- Fastest query method for real-time data

### Mode 2: Archived Data
- Triggered when both `StartTime` and `EndTime` are provided
- Returns all recorded values within the time range
- Uses `AFBoundaryType.Inside` to exclude boundary values
- Queries each tag individually for reliability

## Time Format Examples

The AF SDK accepts various time formats:

- **Absolute**: `"2025-10-15T10:30:00Z"`
- **Relative to now**: `"*"` (current time), `"*-1h"` (1 hour ago), `"*-7d"` (7 days ago)
- **Named times**: `"y"` (yesterday), `"t"` (today)

## Error Handling

The script will exit with an error if:
- AF SDK is not found at the expected path
- Connection to PI Server fails
- Only one of `StartTime` or `EndTime` is provided
- Invalid tag names or time formats are specified

## Troubleshooting

**Error: Cannot find path to AF SDK**
- Verify AF SDK installation path
- Update the path in the script if installed elsewhere

**Error: Cannot connect to PI Server**
- Check network connectivity
- Verify PI Server name
- Confirm user permissions

**No data returned**
- Verify tag names are correct (case-sensitive)
- Check if data exists in the specified time range
- Ensure tags have "Good" quality data

## Performance Notes

- For large time ranges or many tags, archived data queries may take longer
- The script queries archived data per tag for maximum reliability
- Consider narrowing time ranges for better performance

## License

This script is provided as-is for use with OSIsoft PI System installations.