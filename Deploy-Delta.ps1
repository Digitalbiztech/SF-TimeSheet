Write-Host "Scanning for local changes..." -ForegroundColor Cyan

# Get changed files, filter for the timesheet folder, and extract the path
$changedFiles = git status --porcelain | 
    Where-Object { $_ -match "^[ MAU\?]{2}\s+(.*timesheet/main/default/.*)" } | 
    ForEach-Object { $matches[1] }

if (-not $changedFiles) {
    Write-Host "No deployable changes detected in timesheet/main/default." -ForegroundColor Yellow
    exit
}

$deployPaths = @{}

foreach ($file in $changedFiles) {
    # Convert Unix paths from Git to Windows paths
    $winPath = $file -replace "/", "\"
    
    # If LWC or Aura, capture the bundle folder. Otherwise, capture the exact file.
    if ($winPath -match "(.*\\(?:lwc|aura)\\[^\\]+)") {
        $deployPaths[$matches[1]] = $true
    } else {
        $deployPaths[$winPath] = $true
    }
}

# Construct the command dynamically
$command = "sf project deploy start"
foreach ($target in $deployPaths.Keys) {
    $command += " -d `"$target`""
}
$command += " --ignore-conflicts"

Write-Host "`nExecuting:`n$command`n" -ForegroundColor Green

# Run the command
Invoke-Expression $command