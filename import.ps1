$ErrorActionPreference = 'Stop'

$targetOrg = 'testorg2'      # change to your target scratch org alias
$dataDir   = ".\data"        # directory containing the data files
$namespace = "dbt"           # Set your managed package namespace here, or "" for no namespace

# --- Functions ---
function Run-Sfdx {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Args
    )
    if ($Args -contains $null -or $Args.Count -eq 0) {
        throw "Run-Sfdx received empty or null arguments."
    }

    $outFile = [System.IO.Path]::GetTempFileName()
    $errFile = [System.IO.Path]::GetTempFileName()
    try {
        Start-Process -FilePath "sfdx" -ArgumentList $Args -NoNewWindow -RedirectStandardOutput $outFile -RedirectStandardError $errFile -Wait
        $stdout = Get-Content $outFile -Raw -ErrorAction SilentlyContinue
        $stderr = Get-Content $errFile -Raw -ErrorAction SilentlyContinue
        
        $stdOutContent = if ($stdout) { $stdout.TrimEnd() } else { "" }
        $stdErrContent = if ($stderr) { $stderr.TrimEnd() } else { "" }
        return ($stdOutContent + "`n" + $stdErrContent).Trim()

    } finally {
        Remove-Item -ErrorAction SilentlyContinue $outFile, $errFile
    }
}

function Parse-JsonFromCli {
    param($raw)
    if (-not $raw) { throw "Empty CLI output." }
    $first = $raw.IndexOf('{')
    $last  = $raw.LastIndexOf('}')
    if ($first -lt 0 -or $last -lt $first) {
        Write-Host "RAW CLI OUTPUT (for debugging):"
        Write-Host $raw
        throw "Failed to locate JSON braces in CLI output."
    }
    $jsonText = $raw.Substring($first, $last - $first + 1)
    try {
        return $jsonText | ConvertFrom-Json
    } catch {
        Write-Host "EXTRACTED JSON (for debugging):"
        Write-Host $jsonText
        throw "ConvertFrom-Json failed: $($_.Exception.Message)"
    }
}

function Write-JsonWithoutBom {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [object]$JsonObject,
        [int]$Depth = 20
    )
    $utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($false)
    $jsonContent = $JsonObject | ConvertTo-Json -Depth $Depth
    [System.IO.File]::WriteAllText($Path, $jsonContent, $utf8NoBomEncoding)
}


# --- Main Script ---

# Construct the namespace prefix (e.g., "dbt__") if a namespace is provided
$namespacePrefix = if ([string]::IsNullOrWhiteSpace($namespace)) { "" } else { "$namespace`__" }

Write-Host "Target org: $targetOrg"
Write-Host "Data dir: $dataDir"
if ($namespacePrefix) { Write-Host "Namespace: $namespace" }

# 1) Validate files exist
$files = @{
    employee         = "$($namespacePrefix)Employee__c.json"
    project          = "$($namespacePrefix)Project__c.json"
    project_employee = "$($namespacePrefix)Project_Employee__c.json"
    timesheet        = "$($namespacePrefix)Timesheet__c.json"
}
$filePaths = @{}
foreach ($k in $files.Keys) {
    $p = Join-Path $dataDir $files[$k]
    if (-not (Test-Path $p)) { throw "Missing file: $p" }
    $filePaths[$k] = $p
}

# 2) Get current user Id
Write-Host "Getting current user id from org '$targetOrg'..."
$rawUser = Run-Sfdx -Args @("force:user:display", "--target-org", $targetOrg, "--json")
$userObj = Parse-JsonFromCli $rawUser
$currUserId = $userObj.result.id
if (-not $currUserId) { throw "Could not extract current User Id." }
Write-Host "Current User Id: $currUserId"

# 3) Load data files
Write-Host "Loading data files into memory..."
$empJson = Get-Content $filePaths.employee -Raw | ConvertFrom-Json
$projJson = Get-Content $filePaths.project -Raw | ConvertFrom-Json
$peJson = Get-Content $filePaths.project_employee -Raw | ConvertFrom-Json
$tsJson = Get-Content $filePaths.timesheet -Raw | ConvertFrom-Json

# 4) If namespace is present, patch the SObject type for all records in memory
if ($namespacePrefix) {
    Write-Host "Patching SObject types in memory with namespace '$namespace'..."
    foreach ($r in $empJson.records) { $r.attributes.type = "$($namespacePrefix)Employee__c" }
    foreach ($r in $projJson.records) { $r.attributes.type = "$($namespacePrefix)Project__c" }
    foreach ($r in $peJson.records) { $r.attributes.type = "$($namespacePrefix)Project_Employee__c" }
    foreach ($r in $tsJson.records) { $r.attributes.type = "$($namespacePrefix)Timesheet__c" }
    Write-Host "SObject types patched."
}

# 5) Fix all lookup reference fields in memory
Write-Host "Patching lookup reference fields to use '@' syntax..."
$allJsonObjects = @($empJson, $projJson, $peJson, $tsJson)
foreach ($jsonObj in $allJsonObjects) {
    if ($null -ne $jsonObj.records) {
        foreach ($record in $jsonObj.records) {
            $propNames = $record.PSObject.Properties.Name | ForEach-Object { $_ }
            foreach ($propName in $propNames) {
                if ($propName -eq 'attributes') { continue }
                $propValue = $record.$propName
                if ($propValue -is [System.Management.Automation.PSCustomObject] -and $propValue.PSObject.Properties.Name -contains 'reference') {
                    $refId = $propValue.reference
                    $record | Add-Member -MemberType NoteProperty -Name $propName -Value "@$refId" -Force
                }
            }
        }
    }
}
Write-Host "Lookup references patched."

# 6) Patch employee data in memory: set User__c to current user id
$userFieldName = "$($namespacePrefix)User__c"
foreach ($r in $empJson.records) {
    # Add or update the namespaced User__c field on each record
    $r | Add-Member -NotePropertyName $userFieldName -NotePropertyValue $currUserId -Force
}

# 7) Write all modified JSON objects back to disk (this also cleans any BOMs)
Write-Host "Writing all patched data back to source files..."
Write-JsonWithoutBom -Path $filePaths.employee -JsonObject $empJson
Write-JsonWithoutBom -Path $filePaths.project -JsonObject $projJson
Write-JsonWithoutBom -Path $filePaths.project_employee -JsonObject $peJson
Write-JsonWithoutBom -Path $filePaths.timesheet -JsonObject $tsJson
Write-Host "Patched $($files.employee) -> set $userFieldName = $currUserId"
Write-Host "Source files updated."

# 8) Create plan.json
$plan = @(
    @{ sobject = "$($namespacePrefix)Employee__c"; files = @($files.employee) },
    @{ sobject = "$($namespacePrefix)Project__c"; files = @($files.project) },
    @{ sobject = "$($namespacePrefix)Project_Employee__c"; files = @($files.project_employee) },
    @{ sobject = "$($namespacePrefix)Timesheet__c"; files = @($files.timesheet) }
)
$planPath = Join-Path $dataDir "plan.json"
Write-JsonWithoutBom -Path $planPath -JsonObject $plan -Depth 10
Write-Host "Wrote plan.json -> $planPath"

# 9) Run import
Write-Host "Running import with --json for detailed error output..."
$rawImport = Run-Sfdx -Args @("force:data:tree:import", "--plan", $planPath, "--target-org", $targetOrg, "--json")

# 10) Process import result
Write-Host "--- Import Result ---"
Write-Host $rawImport
Write-Host "---------------------"

try {
    # Use the robust Parse-JsonFromCli function to handle extra text in the output
    $importResult = Parse-JsonFromCli $rawImport
    if ($importResult.status -ne 0) {
        Write-Warning "Import failed. Details from --json output:"
        if ($importResult.name) { Write-Warning ("Name: " + $importResult.name) }
        if ($importResult.message) { Write-Warning ("Message: " + $importResult.message) }
    } else {
         Write-Host "Import successful."
    }
} catch {
    # Fallback for non-json output or parsing errors
    if ($rawImport -match "Successfully imported" -or $rawImport -match "Success") {
        Write-Host "Import looks successful based on string match."
    } else {
        Write-Warning "Could not parse JSON from import result. Inspect the raw output above for errors."
    }
}

