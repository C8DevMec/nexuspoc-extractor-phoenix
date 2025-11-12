<#
.SYNOPSIS
    Fetches PI data using the AF SDK directly for a list of tags.
    Supports both snapshot and archived data queries. (Final corrected version)
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$TagNames,

    [Parameter(Mandatory=$false)]
    [string]$StartTime,

    [Parameter(Mandatory=$false)]
    [string]$EndTime,

    [Parameter(Mandatory=$false)]
    [string]$ServerName = $null
)

try {
    # Step 1: Load AF SDK
    Add-Type -Path "C:\Program Files (x86)\PIPC\AF\PublicAssemblies\4.0\OSIsoft.AFSDK.dll" -ErrorAction Stop

    # Step 2: Connect to PI Server
    $piServers = New-Object OSIsoft.AF.PI.PIServers
    $piServer = if ($ServerName) { $piServers[$ServerName] } else { $piServers.DefaultPIServer }
    if (-not $piServer.ConnectionInfo.IsConnected) { $piServer.Connect($false) }

    # Step 3: Find all requested PI Points in a single bulk call for efficiency
    $tagArray = $TagNames.Split(',')
    $piPointList = [OSIsoft.AF.PI.PIPoint]::FindPIPoints($piServer, $tagArray)

    # Step 4: Initialize the array to hold all results
    $results = @()

    # Step 5: Decide which data to fetch
    if (-not $StartTime -and -not $EndTime) {
        # --- MODE 1: SNAPSHOT DATA (This logic was already working) ---
        $afValues = $piPointList.Snapshot()
        foreach ($afValue in $afValues) {
            if ($afValue.IsGood) {
                $results += [PSCustomObject]@{
                    TagName   = $afValue.PIPoint.Name
                    Value     = $afValue.Value
                    Timestamp = $afValue.Timestamp.UtcTime.ToString("o")
                    IsGood    = $afValue.IsGood
                }
            }
        }
    }
    else {
        # --- MODE 2: ARCHIVED DATA (Using the proven debug logic) ---
        if (-not $StartTime -or -not $EndTime) {
            throw "For archived data, both -StartTime and -EndTime parameters are required."
        }
        
        # Create the time range object once
        $timeRange = New-Object OSIsoft.AF.Time.AFTimeRange($StartTime, $EndTime)

        # Loop through each point found and get its values individually.
        # This uses the exact same method that was proven to work in Debug-Archive.ps1
        foreach ($point in $piPointList) {
            $afValuesForPoint = $point.RecordedValues($timeRange, [OSIsoft.AF.Data.AFBoundaryType]::Inside, $null, $false, 0)
            
            # Now loop through the results for this single point
            foreach ($val in $afValuesForPoint) {
                if ($val.IsGood) {
                    $results += [PSCustomObject]@{
                        TagName   = $point.Name
                        Value     = $val.Value
                        Timestamp = $val.Timestamp.UtcTime.ToString("o")
                        IsGood    = $val.IsGood
                    }
                }
            }
        }
    }

    # Step 6: Convert the final, combined results to JSON and output
    $jsonOutput = $results | ConvertTo-Json -Compress
    Write-Output $jsonOutput
}
catch {
    Write-Error $_.Exception.ToString()
    exit 1
}
