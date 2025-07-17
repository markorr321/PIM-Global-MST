<#
  Unified Global PIM Script using MSAL.NET DLLs (No MSAL.PS)
  ----------------------------------------------------------
  - Supports multi-tenant access
  - System browser auth (MFA enforced with ACRS claims)
  - Connects to Graph using direct access token
  - Prompts for PIM role, duration, justification
  - Submits PIM activation request
#>

# ========================= Environment Validation =========================

# PowerShell 7+ Required
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "`n[ERROR] PowerShell 7 or higher is required to run this script." -ForegroundColor Red
    Write-Host "You are currently using: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
    Write-Host "Please launch with pwsh.exe, not powershell.exe." -ForegroundColor Cyan
    exit 1
}

# ========================= Load MSAL.NET DLLs (netstandard2.0 for PS7) =========================
$scriptBase = $PSScriptRoot
$msalSubPath = "MSAL\netstandard2.0"
$clientDll = Join-Path $scriptBase "$msalSubPath\Microsoft.Identity.Client.dll"
$abstractionsDll = Join-Path $scriptBase "$msalSubPath\Microsoft.IdentityModel.Abstractions.dll"

# fallback if running in temp or redirected launcher
if (-not (Test-Path $clientDll) -or -not (Test-Path $abstractionsDll)) {
    $scriptBase = (Get-Location).Path
    $clientDll = Join-Path $scriptBase "$msalSubPath\Microsoft.Identity.Client.dll"
    $abstractionsDll = Join-Path $scriptBase "$msalSubPath\Microsoft.Identity.Model.Abstractions.dll"
}

if (-not (Test-Path $clientDll) -or -not (Test-Path $abstractionsDll)) {
    Write-Host "`n[ERROR] Required MSAL.NET DLLs not found in: $scriptBase\$msalSubPath`n" -ForegroundColor Red
    Write-Host "Missing files:" -ForegroundColor Yellow
    if (-not (Test-Path $clientDll)) { Write-Host " - $clientDll" -ForegroundColor Red }
    if (-not (Test-Path $abstractionsDll)) { Write-Host " - $abstractionsDll" -ForegroundColor Red }
    exit 1
}

# Prevent duplicate load or locked file warnings
try {
    Add-Type -Path $clientDll -ErrorAction Stop
    Add-Type -Path $abstractionsDll -ErrorAction Stop
} catch {
    Write-Host "[INFO] DLLs already loaded or in use. Continuing..." -ForegroundColor Yellow
}

# ========================= Module Dependencies =========================

if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Write-Host "`n[ERROR] Microsoft.Graph.Authentication is not installed or not discoverable via PSModulePath." -ForegroundColor Red
    Write-Host "Install it using:" -ForegroundColor Cyan
    Write-Host " Install-Module Microsoft.Graph -Scope CurrentUser -Force" -ForegroundColor White
    exit 1
}

try {
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
} catch {
    Write-Host "`n[ERROR] Failed to import Microsoft.Graph.Authentication module: $_" -ForegroundColor Red
    exit 1
}

# ========================= Define Window Focus PInvoke =========================
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
}
"@

function Invoke-FocusTerminal {
    $hwnd = [Win32]::GetConsoleWindow()
    $null = [Win32]::ShowWindow($hwnd, 5)  # SW_SHOW = 5 to activate and display
    $null = [Win32]::SetForegroundWindow($hwnd)
}

# ========================= Config =========================
$clientId = "bf34fc64-bbbc-45cb-9124-471341025093"
$tenantId = "common"
$redirectUri = "http://localhost"
$claims = '{"access_token":{"acrs":{"essential":true,"value":"c1"}}}'
$scopes = @("https://graph.microsoft.com/.default")

# ========================= Authenticate via MSAL.NET =========================
$app = [Microsoft.Identity.Client.PublicClientApplicationBuilder]::Create($clientId).
        WithTenantId($tenantId).
        WithRedirectUri($redirectUri).
        Build()

$params = New-Object "System.Collections.Generic.Dictionary``2[System.String,System.String]"
$params.Add("claims", $claims)

try {
    $accounts = $app.GetAccountsAsync().Result
    foreach ($account in $accounts) {
        $app.RemoveAsync($account).Wait()
    }

    $builder = $app.AcquireTokenInteractive([string[]]$scopes)
    $builder = $builder.WithPrompt([Microsoft.Identity.Client.Prompt]::ForceLogin)
    $builder = $builder.WithExtraQueryParameters($params)
    $builder = $builder.WithUseEmbeddedWebView($false)
    $tokenResult = $builder.ExecuteAsync().GetAwaiter().GetResult()

    Start-Sleep -Milliseconds 500  # Short delay to allow browser success page to load
    Invoke-FocusTerminal  # Focus immediately after auth

    $accessToken = $tokenResult.AccessToken
    $tenantId = $tokenResult.TenantId
    $secureToken = ConvertTo-SecureString $accessToken -AsPlainText -Force

    Connect-MgGraph -AccessToken $secureToken -ErrorAction Stop | Out-Null
    $context = Get-MgContext

    Write-Host ""
    Write-Host "Connected with MFA-Compliant Token" -ForegroundColor DarkGreen
    Write-Host "User: $($context.Account)" -ForegroundColor Cyan
    Write-Host "Tenant: $tenantId" -ForegroundColor Cyan
    Write-Host ""

    Invoke-FocusTerminal  # Focus again after messages, in case

} catch {
    Write-Host ""
    Write-Host "[ERROR] Failed to authenticate: $_" -ForegroundColor DarkRed
    exit
}

# ========================= Utility: Flush-ConsoleInput =========================
function Flush-ConsoleInput {
    while ([Console]::KeyAvailable) {
        [Console]::ReadKey($true) | Out-Null
    }
}

# ========================= Get Eligible Roles =========================
$currentUser = (Get-MgUser -UserId $context.Account).Id
$myRoles = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -ExpandProperty RoleDefinition -All -Filter "principalId eq '$currentUser'"
$validRoles = $myRoles | Where-Object { $_.RoleDefinition -and $_.RoleDefinition.DisplayName }

if ($validRoles.Count -eq 0) {
    Write-Host ""
    Write-Host "You do not have any eligible roles for activation." -ForegroundColor DarkRed
    Write-Host ""
    Write-Host "Press Enter to exit..." -ForegroundColor Yellow
    Read-Host
    exit
}

Write-Host "Available Roles for Activation:" -ForegroundColor Cyan
Write-Host ""
$index = 1
$roleMap = @{}
foreach ($role in $validRoles) {
    Write-Host ("[{0}] {1}" -f $index, $role.RoleDefinition.DisplayName)
    $roleMap[$index] = $role
    $index++
}

# ========================= Prompt for Role =========================
Write-Host ""
do {
    $selection = Read-Host "Enter the number corresponding to the role you want to activate"
    if ([string]::IsNullOrWhiteSpace($selection) -or -not ($selection -match '^\d+$') -or [int]$selection -le 0 -or [int]$selection -gt $roleMap.Count) {
        Write-Host "ERROR: Invalid selection." -ForegroundColor DarkRed
        $selection = $null
    }
} while (-not $selection)

Flush-ConsoleInput
$myRole = $roleMap[[int]$selection]

# ========================= Prompt for Duration =========================
Write-Host ""
do {
    $durationInput = Read-Host "Enter activation duration (e.g., 1H, 30M, 2H30M)"
    if ([string]::IsNullOrWhiteSpace($durationInput) -or $durationInput -notmatch '^\d+[HM]') {
        Write-Host "ERROR: Invalid format. Use '1H', '30M', or '2H30M'." -ForegroundColor DarkRed
        $durationInput = $null
    }
} while (-not $durationInput)

$duration = $durationInput.ToUpper() -replace '(\d+)H', 'PT${1}H' -replace '(\d+)M', '${1}M'
if ($duration -match '^\d+M$') { $duration = "PT$duration" }

# ========================= Prompt for Justification =========================
Write-Host ""
do {
    $justification = Read-Host "Enter reason for activation"
    if ([string]::IsNullOrWhiteSpace($justification)) {
        Write-Host "ERROR: Justification required." -ForegroundColor DarkRed
        $justification = $null
    }
} while (-not $justification)

Flush-ConsoleInput

# ========================= Check if Already Active =========================
try {
    $activeRoleAssignments = Get-MgRoleManagementDirectoryRoleAssignment `
        -Filter "principalId eq '$($myRole.PrincipalId)' and roleDefinitionId eq '$($myRole.RoleDefinitionId)'"
    if ($activeRoleAssignments) {
        Write-Host ""
        Write-Host "ERROR: Role is already active." -ForegroundColor DarkRed
        Write-Host ""
        Write-Host "Press Enter to exit..." -ForegroundColor Yellow
        Read-Host
        Disconnect-MgGraph | Out-Null
        exit
    }
} catch {
    Write-Host ""
    Write-Host "Warning: Could not check existing assignment. Continuing..." -ForegroundColor Cyan
    Write-Host ""
}

# ========================= Build & Submit Activation =========================
$directoryScopeId = if ([string]::IsNullOrEmpty($myRole.DirectoryScopeId)) { "/" } else { $myRole.DirectoryScopeId }

$params = @{
    Action           = "selfActivate"
    PrincipalId      = $myRole.PrincipalId
    RoleDefinitionId = $myRole.RoleDefinitionId
    DirectoryScopeId = $directoryScopeId
    Justification    = $justification
    ScheduleInfo     = @{
        StartDateTime = Get-Date
        Expiration    = @{
            Type     = "AfterDuration"
            Duration = $duration
        }
    }
}

try {
    $null = New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $params
    $expiry = (Get-Date).Add([System.Xml.XmlConvert]::ToTimeSpan($duration))
    $formattedExpiry = $expiry.ToString("MM/dd/yyyy hh:mm:ss tt")

    Write-Host ""
    Write-Host "Role activation request submitted successfully!" -ForegroundColor DarkBlue
    Write-Host ""
    Write-Host "Activated Role: $($myRole.RoleDefinition.DisplayName)" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "Role will expire at: $formattedExpiry" -ForegroundColor DarkCyan
    Write-Host ""
} catch {
    $msg = $_.Exception.Message
    Write-Host ""
    if ($msg -match "RoleAssignmentExists") {
        Write-Host "ERROR: Role is already active." -ForegroundColor DarkRed
    } elseif ($msg -match "PendingRoleAssignmentRequest") {
        Write-Host "ERROR: Pending request already exists." -ForegroundColor DarkRed
    } elseif ($msg -match "RoleAssignmentRequestAcrsValidationFailed") {
        Write-Host "ERROR: MFA session not valid (acrs=c1 not met)." -ForegroundColor DarkRed
    } else {
        Write-Host "ERROR: $msg" -ForegroundColor DarkRed
    }
    Write-Host ""
    Write-Host "Press Enter to exit..." -ForegroundColor Yellow
    Read-Host
}

Disconnect-MgGraph | Out-Null
Write-Host "You have been disconnected from Microsoft Graph." -ForegroundColor DarkRed
Write-Host ""
Write-Host "Press Enter to exit..." -ForegroundColor Yellow
Read-Host 