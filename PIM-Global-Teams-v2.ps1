<#
    Global PIM Manager Script (Activation + Deactivation) with Teams Notifications
    ------------------------------------------------------------------------------
    - Detects and deactivates active roles (with justification)
    - Falls back to activation if no roles are active
    - Supports group-based and user-based eligibilities
    - MFA-enforced MSAL login via browser
    - Sends Teams notifications via webhook for successful operations
    
    FEATURES:
    =========
    
    🔔 Teams Integration:
       - Automatic notifications for successful role activations and deactivations
       - Rich adaptive cards with role details, user info, and timestamps
       - Configurable webhook URL and notification toggle
       - Timezone-aware timestamps with proper abbreviations
    
    📋 Adaptive Card Features:
       - Role operation type (Activation/Deactivation) with appropriate icons
       - User email, role name, and justification
       - Duration and expiry time for activations
       - Localized date/time with timezone abbreviation
       - Color-coded themes (Blue for activation, Orange for deactivation)
    
    ⚙️ Configuration:
       - Set $teamsWebhookUrl to your Teams webhook URL
       - Set $enableTeamsNotifications to $false to disable notifications
       - Webhook creation guide: Teams Channel → More options → Manage channel → Edit → Incoming Webhook → Add
    
    📚 References:
       - Microsoft Teams Webhooks: https://learn.microsoft.com/en-us/microsoftteams/platform/webhooks-and-connectors/how-to/add-incoming-webhook
       - Adaptive Cards Schema: http://adaptivecards.io/schemas/adaptive-card.json
#>

# ========================= PIM-Global Branding Header =========================
Clear-Host
Write-Host "[ P I M - G L O B A L ]" -ForegroundColor DarkMagenta
Write-Host "PIM-Global - Automate PIM Role Activation Application via Microsoft Entra ID" -ForegroundColor Green
Write-Host "Made by Mark Orr with " -NoNewline -ForegroundColor White
Write-Host "☕ 3 cups of coffee " -NoNewline -ForegroundColor Yellow
Write-Host "and " -NoNewline -ForegroundColor White
Write-Host "🥤 6 diet cokes! " -NoNewline -ForegroundColor Red
Write-Host "Dedicated to Courtney and Aubrey" -ForegroundColor Magenta
Write-Host "Version 3.0.0 | Release: 08.13.2025" -ForegroundColor Gray
Write-Host ""
Write-Host "This is a private version of the application. Feedback welcome at:" -ForegroundColor Yellow
Write-Host "Issues: " -NoNewline -ForegroundColor White
Write-Host "https://github.com/markorr321/PIM-Global-MST/issues" -ForegroundColor Blue
Write-Host ""
Write-Host "Love this tool? Consider sponsoring development:" -ForegroundColor White
Write-Host "GitHub: " -NoNewline -ForegroundColor White
Write-Host "https://github.com/sponsors/markorr321" -ForegroundColor Blue
Write-Host "Development opportunities: " -NoNewline -ForegroundColor White
Write-Host "morr@orr365.tech" -ForegroundColor Cyan
Start-Sleep -Seconds 3

# ========================= Module Dependencies =========================
$ErrorActionPreference = "SilentlyContinue"

if (-not (Get-Module -Name MSAL.PS) -and -not (Get-Module -ListAvailable -Name MSAL.PS)) {
    Install-Module MSAL.PS -Scope CurrentUser -Force
}
if (-not (Get-Module -Name Microsoft.Graph) -and -not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
    Install-Module Microsoft.Graph -Scope CurrentUser -Force
}

# ========================= Teams Webhook Configuration =========================
# Configure your Teams webhook URL here
# To create a webhook: Teams Channel → More options → Manage channel → Edit → Incoming Webhook → Add
$teamsWebhookUrl = "https://cmaorrtech.webhook.office.com/webhookb2/102682b7-85c6-4c3e-b98b-c3b460fe8011@51eb883f-451f-4194-b108-4df354b35bf4/IncomingWebhook/33c507565393483ab034c8d19ed3c1fb/8cc8faec-1b97-40f0-ab11-eddcf89d54a1/V2HLN3VPRcvQK5pVYjkVjRpzG6-seyiOIzAXbXB0U8e9A1"

# Approval channel webhook URL (for approval-required roles)
$approvalChannelWebhookUrl = "https://cmaorrtech.webhook.office.com/webhookb2/d4f674d6-36f8-4e0a-9d2a-7cdb5d3bf196@51eb883f-451f-4194-b108-4df354b35bf4/IncomingWebhook/f2192c4bc3cf48fca3fcb5e93cb4d45a/8cc8faec-1b97-40f0-ab11-eddcf89d54a1/V21J6fdDWCg3a4nctZ5U_fF7NGWprF4HPd6EYQEORq4kk1"

# Power Automate URL for interactive approvals (for immediate activation roles)
$powerAutomateApprovalUrl = "https://default51eb883f451f4194b1084df354b35b.f4.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/6805f3b5957f452d96dafd153561d04d/triggers/manual/paths/invoke/?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=oARAEv9M68wOCUwUMDpt1oEiqDd7We84z3f6aY45h2A"

# Enable/disable Teams notifications
$enableTeamsNotifications = $true

# Enable/disable batching multiple role requests into single approval
$enableBatchApprovals = $false

# Azure PIM Portal URL for approvals
$pimApprovalUrl = "https://portal.azure.com/?Microsoft_Azure_PIMCommon=true#view/Microsoft_Azure_PIMCommon/ApproveRequestMenuBlade/~/aadmigratedroles"

# ========================= Teams Notification Functions =========================
function Get-TimeZoneAbbreviation {
    $tz = Get-TimeZone
    $now = Get-Date
    $offset = $tz.GetUtcOffset($now)
    $isDst = $tz.IsDaylightSavingTime($now)
    $abbr = $tz.Id
    # Try to get a common abbreviation
    switch ($tz.Id) {
        'Pacific Standard Time' { $abbr = if ($isDst) { 'PDT' } else { 'PST' } }
        'Mountain Standard Time' { $abbr = if ($isDst) { 'MDT' } else { 'MST' } }
        'Central Standard Time' { $abbr = if ($isDst) { 'CDT' } else { 'CST' } }
        'Eastern Standard Time' { $abbr = if ($isDst) { 'EDT' } else { 'EST' } }
        'UTC' { $abbr = 'UTC' }
        default { $abbr = $tz.Id }
    }
    return $abbr
}

function Send-TeamsNotification {
    param(
        [string]$Operation,
        [string]$UserEmail,
        [string]$RoleName,
        [string]$Duration,
        [string]$Justification,
        [string]$ExpiryTime = ""
    )
    
    # Check if Teams notifications are enabled
    if (-not $enableTeamsNotifications) {
        return $false
    }
    
    $localNow = (Get-Date).ToLocalTime()
    $dateString = $localNow.ToString("MM/dd/yyyy")
    $timeString = $localNow.ToString("h:mm tt")
    $tzAbbreviation = Get-TimeZoneAbbreviation
    
    $operationIcon = if ($Operation -eq "Activation") { "🔓" } else { "🔒" }
    $operationColor = if ($Operation -eq "Activation") { "Good" } else { "Warning" }
    
    # Build facts array with null checks to prevent "null key" errors
    $facts = @()
    
    # Build facts array with null checks to prevent "null key" errors
    if ($UserEmail -and $UserEmail.Trim()) { 
        $facts += @{ title = "User:"; value = $UserEmail.Trim() } 
    }
    if ($RoleName -and $RoleName.Trim()) { 
        $facts += @{ title = "Role:"; value = $RoleName.Trim() } 
    }
    if ($Justification -and $Justification.Trim()) { 
        $facts += @{ title = "Justification:"; value = $Justification.Trim() } 
    }
    if ($dateString -and $dateString.Trim()) { 
        $facts += @{ title = "Date:"; value = $dateString.Trim() } 
    }
    if ($timeString -and $tzAbbreviation -and $timeString.Trim() -and $tzAbbreviation.Trim()) { 
        $facts += @{ title = "Time:"; value = "$($timeString.Trim()) $($tzAbbreviation.Trim())" } 
    }
    
    if ($Operation -eq "Activation" -and $Duration -and $Duration.Trim()) {
        $facts += @{ title = "Duration:"; value = $Duration.Trim() }
    }
    
    if ($Operation -eq "Activation" -and $ExpiryTime -and $ExpiryTime.Trim()) {
        $facts += @{ title = "Expires:"; value = $ExpiryTime.Trim() }
    }
    
    # Create adaptive card with explicit null checks
    $cardBody = @(
        @{ type = "TextBlock"; text = "$operationIcon PIM Role $Operation"; weight = "Bolder"; size = "Large" },
        @{ type = "TextBlock"; text = "A PIM role has been successfully $($Operation.ToLower())."; wrap = $true }
    )
    
    # Only add FactSet if we have facts
    if ($facts.Count -gt 0) {
        $cardBody += @{ type = "FactSet"; facts = $facts }
    }
    
    $cardContent = @{
        type = "AdaptiveCard"
        version = "1.4"
        body = $cardBody
        themeColor = if ($Operation -eq "Activation") { "0078D4" } else { "FF8C00" }
    }
    
    # Add schema property using a different method to avoid PowerShell variable conflicts
    $cardContent | Add-Member -NotePropertyName '$schema' -NotePropertyValue "http://adaptivecards.io/schemas/adaptive-card.json" -Force
    
    $adaptiveCard = @{
        type = "message"
        attachments = @(@{
            contentType = "application/vnd.microsoft.card.adaptive"
            content = $cardContent
        })
    }
    
    $jsonCard = $adaptiveCard | ConvertTo-Json -Depth 8

    try {
        # Validate that we have at least some facts before sending
        if ($facts.Count -eq 0) {
            Write-Host "⚠️ No valid facts to send in Teams notification" -ForegroundColor Yellow
            return $false
        }
        
        $response = Invoke-RestMethod -Uri $teamsWebhookUrl -Method Post -ContentType 'application/json' -Body $jsonCard
        return $true
    } catch {
        Write-Host "⚠️ Teams workflow not configured - continuing without notifications" -ForegroundColor Yellow
        return $false
    }
}

function Send-PowerAutomateApproval {
    param(
        [string]$TrackingId,
        [string]$UserEmail,
        [string]$UserDisplayName,
        [string]$RoleName,
        [string]$Duration,
        [string]$Justification,
        [string]$ActivationId,
        [string]$ExpiryTime
    )
    
    if (-not $enableTeamsNotifications) {
        return $false
    }
    
    $approvalData = @{
        trackingId = $TrackingId
        userEmail = $UserEmail
        userDisplayName = $UserDisplayName
        roleName = $RoleName
        roleNamesFormatted = "• $RoleName"
        duration = $Duration
        justification = $Justification
        activationId = $ActivationId
        expiryTime = $ExpiryTime
        isBatch = $false
    }
    
    try {
        $jsonBody = $approvalData | ConvertTo-Json -Depth 10
        
        $response = Invoke-RestMethod -Uri $powerAutomateApprovalUrl -Method Post -Body $jsonBody -ContentType "application/json"
        return $true
    } catch {
        Write-Host "⚠️ Power Automate workflow not configured - continuing without approval automation" -ForegroundColor Yellow
        return $false
    }
}

function Send-BatchedPowerAutomateApproval {
    param(
        [string]$TrackingId,
        [string]$UserEmail,
        [string]$UserDisplayName,
        [array]$Roles,
        [string]$Duration,
        [string]$Justification
    )
    
    if (-not $enableTeamsNotifications) {
        return $false
    }
    
    # Create a formatted string of role names for display
    $roleNamesFormatted = ($Roles | ForEach-Object { "• $($_.roleName)" }) -join "`n"
    
    $approvalData = @{
        trackingId = $TrackingId
        userEmail = $UserEmail
        userDisplayName = $UserDisplayName
        roles = $Roles
        roleNamesFormatted = $roleNamesFormatted
        duration = $Duration
        justification = $Justification
        isBatch = $true
    }
    
    try {
        $jsonBody = $approvalData | ConvertTo-Json -Depth 10
        
        $response = Invoke-RestMethod -Uri $powerAutomateApprovalUrl -Method Post -Body $jsonBody -ContentType "application/json"
        return $true
    } catch {
        Write-Host "⚠️ Power Automate workflow not configured - continuing without approval automation" -ForegroundColor Yellow
        return $false
    }
}

function Send-ApprovalRequiredNotification {
    param(
        [string]$UserEmail,
        [string]$RoleName,
        [string]$Duration,
        [string]$Justification,
        [string]$RequestId
    )
    
    if (-not $enableTeamsNotifications) {
        return $false
    }
    
    # Get timezone info for proper timestamp display
    $timeZone = [System.TimeZoneInfo]::Local
    $currentTime = Get-Date
    $timeZoneAbbr = if ($timeZone.IsDaylightSavingTime($currentTime)) { $timeZone.DaylightName } else { $timeZone.StandardName }
    $timeZoneAbbr = $timeZoneAbbr -replace "Time", "" -replace " ", ""
    
    $card = @{
        type = "message"
        attachments = @(
            @{
                contentType = "application/vnd.microsoft.card.adaptive"
                content = @{
                    '$schema' = "http://adaptivecards.io/schemas/adaptive-card.json"
                    type = "AdaptiveCard"
                    version = "1.3"
                    body = @(
                        @{
                            type = "Container"
                            style = "attention"
                            items = @(
                                @{
                                    type = "ColumnSet"
                                    columns = @(
                                        @{
                                            type = "Column"
                                            width = "auto"
                                            items = @(
                                                @{
                                                    type = "TextBlock"
                                                    text = "⏳"
                                                    size = "Large"
                                                    horizontalAlignment = "Center"
                                                }
                                            )
                                        }
                                        @{
                                            type = "Column"
                                            width = "stretch"
                                            items = @(
                                                @{
                                                    type = "TextBlock"
                                                    text = "**PIM Role Activation - Approval Required**"
                                                    weight = "Bolder"
                                                    size = "Medium"
                                                    color = "Attention"
                                                }
                                                @{
                                                    type = "TextBlock"
                                                    text = "A privileged role activation request is pending approval"
                                                    wrap = $true
                                                    color = "Default"
                                                }
                                            )
                                        }
                                    )
                                }
                            )
                        }
                        @{
                            type = "Container"
                            items = @(
                                @{
                                    type = "FactSet"
                                    facts = @(
                                        @{
                                            title = "**Requester:**"
                                            value = $UserEmail
                                        }
                                        @{
                                            title = "**Role:**"
                                            value = $RoleName
                                        }
                                        @{
                                            title = "**Duration:**"
                                            value = $Duration
                                        }
                                        @{
                                            title = "**Justification:**"
                                            value = $Justification
                                        }
                                        @{
                                            title = "**Request Time:**"
                                            value = "$(Get-Date -Format 'MM/dd/yyyy hh:mm:ss tt') $timeZoneAbbr"
                                        }
                                        @{
                                            title = "**Status:**"
                                            value = "⏳ **Pending Approval**"
                                        }
                                    )
                                }
                            )
                        }
                        @{
                            type = "Container"
                            style = "emphasis"
                            items = @(
                                @{
                                    type = "TextBlock"
                                    text = "🔗 **Action Required**"
                                    weight = "Bolder"
                                    color = "Accent"
                                }
                                @{
                                    type = "TextBlock"
                                    text = "Click the button below to review and approve/deny this request in the Azure PIM portal."
                                    wrap = $true
                                    spacing = "Small"
                                }
                            )
                        }
                    )
                    actions = @(
                        @{
                            type = "Action.OpenUrl"
                            title = "🔍 Review in Azure PIM"
                            url = $pimApprovalUrl
                            style = "positive"
                        }
                    )
                }
            }
        )
    }
    
    try {
        $jsonBody = $card | ConvertTo-Json -Depth 20
        Write-Host "🔄 Sending approval-required notification to Teams..." -ForegroundColor Cyan
        
        $response = Invoke-RestMethod -Uri $approvalChannelWebhookUrl -Method Post -Body $jsonBody -ContentType "application/json"
        Write-Host "✅ Approval notification sent to Teams" -ForegroundColor Green
        Write-Host "   Approvers will receive Azure PIM email and can click the Teams card to access the portal" -ForegroundColor Gray
        return $true
    } catch {
        Write-Host "⚠️ Teams approval workflow not configured - continuing without notifications" -ForegroundColor Yellow
        return $false
    }
}

function Send-PostActivationNotification {
    param(
        [string]$UserEmail,
        [string]$RoleName,
        [string]$Duration,
        [string]$Justification,
        [string]$ActivationId,
        [string]$ExpiryTime
    )
    
    if (-not $enableTeamsNotifications) {
        return $false
    }
    
    $localNow = (Get-Date).ToLocalTime()
    $dateString = $localNow.ToString("MM/dd/yyyy")
    $timeString = $localNow.ToString("h:mm tt")
    $tzAbbreviation = Get-TimeZoneAbbreviation
    
    # Generate tracking ID
    $trackingId = "PIM-ACT-" + (Get-Date).ToString("yyyyMMdd-HHmmss") + "-" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
    
    # Create adaptive card for post-activation approval
    $cardBody = @(
        @{
            type = "TextBlock"
            text = "🔓 **PIM Role Activated - Post-Activation Review**"
            size = "Large"
            weight = "Bolder"
            color = "Attention"
        },
        @{
            type = "FactSet"
            facts = @(
                @{ title = "Tracking ID:"; value = $trackingId },
                @{ title = "User:"; value = $UserEmail },
                @{ title = "Role:"; value = $RoleName },
                @{ title = "Duration:"; value = $Duration },
                @{ title = "Activated:"; value = "$dateString $timeString $tzAbbreviation" },
                @{ title = "Expires:"; value = $ExpiryTime },
                @{ title = "Activation ID:"; value = $ActivationId }
            )
        }
    )
    
    # Add justification if provided
    if ($Justification -and $Justification.Trim()) {
        $cardBody += @{
            type = "TextBlock"
            text = "**Justification:**"
            weight = "Bolder"
            wrap = $true
        }
        $cardBody += @{
            type = "TextBlock"
            text = $Justification.Trim()
            wrap = $true
            isSubtle = $true
        }
    }
    
    # Note: Input fields are not supported in webhook-based adaptive cards
    # They only work in bot-based scenarios, so we'll add a note instead
    $cardBody += @{
        type = "TextBlock"
        text = "**Approver Action Required:**"
        weight = "Bolder"
        wrap = $true
        spacing = "Medium"
    }
    
    $cardBody += @{
        type = "TextBlock"
        text = "Please review this activation and take appropriate action if needed."
        wrap = $true
        isSubtle = $true
    }
    
    # Add informational note about follow-up actions
    $cardBody += @{
        type = "TextBlock"
        text = "💼 For approval workflow or escalation, contact the security team or use your organization's standard approval process."
        wrap = $true
        isSubtle = $true
        spacing = "Medium"
    }
    
    $adaptiveCard = @{
        type = "AdaptiveCard"
        version = "1.0"
        body = $cardBody
    }
    
    $message = @{
        type = "message"
        attachments = @(
            @{
                contentType = "application/vnd.microsoft.card.adaptive"
                content = $adaptiveCard
            }
        )
    }
    
    try {
        $jsonBody = $message | ConvertTo-Json -Depth 10
        Write-Host "🔍 Sending to approval channel: $($approvalChannelWebhookUrl.Substring(0,50))..." -ForegroundColor Cyan
        
        $response = Invoke-RestMethod -Uri $approvalChannelWebhookUrl -Method Post -Body $jsonBody -ContentType "application/json"
        Write-Host "✅ Post-activation notification sent to approval channel" -ForegroundColor Green
        Write-Host "   Response: $response" -ForegroundColor Gray
        return $true
    } catch {
        Write-Host "❌ Failed to send post-activation notification: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   Error Details: $($_.Exception)" -ForegroundColor DarkRed
        return $false
    }
}

# ========================= 1) Config & Login =========================
$clientId = "bf34fc64-bbbc-45cb-9124-471341025093"
$tenantId = "common"
$claimsJson = '{"access_token":{"acrs":{"essential":true,"value":"c1"}}}'
$extraParams = @{ "claims" = $claimsJson }

$scopesDelegated = @(
    "User.Read",
    "GroupMember.Read.All",
    "RoleManagement.Read.Directory",
    "RoleManagement.ReadWrite.Directory",
    "Directory.Read.All"
)

$tokenResult = Get-MsalToken -ClientId $clientId `
                             -TenantId $tenantId `
                             -Scopes $scopesDelegated `
                             -Interactive `
                             -Prompt SelectAccount `
                             -ExtraQueryParameters $extraParams

$accessToken = $tokenResult.AccessToken
$tenantId = $tokenResult.TenantId
$secureToken = ConvertTo-SecureString $accessToken -AsPlainText -Force
Connect-MgGraph -AccessToken $secureToken -ErrorAction Stop | Out-Null
$context = Get-MgContext
$currentUser = Get-MgUser -UserId $context.Account
$currentUserId = $currentUser.Id

Write-Host ""
Write-Host "✅ Connected with MFA-Compliant Token" -ForegroundColor DarkGreen
Write-Host "User: $($context.Account)" -ForegroundColor Cyan
Write-Host "Tenant: $tenantId" -ForegroundColor Cyan
Write-Host ""

function Flush-ConsoleInput {
    while ([Console]::KeyAvailable) {
        [Console]::ReadKey($true) | Out-Null
    }
}

# ========================= 2) Detect Active Roles =========================
# Use the working logic from PIM-Global.ps1 - simple direct assignment detection
$activeRoles = @()
$userAssignments = Get-MgRoleManagementDirectoryRoleAssignment -All | Where-Object { $_.PrincipalId -eq $currentUserId }

foreach ($assignment in $userAssignments) {
    $roleDef = Get-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $assignment.RoleDefinitionId
    $activeRoles += [PSCustomObject]@{
        Assignment = $assignment
        RoleName   = $roleDef.DisplayName
    }
}

if ($activeRoles.Count -gt 0) {
    Write-Host "You currently have active PIM role(s):" -ForegroundColor Yellow
    $i = 1
    $activeMap = @{}
    foreach ($entry in $activeRoles) {
        $assignment = $entry.Assignment
        $scopeDisplay = if ($assignment.DirectoryScopeId -ne "/") { " (Scope: $($assignment.DirectoryScopeId))" } else { "" }
        Write-Host "[$i] $($entry.RoleName)$scopeDisplay"
        $activeMap[$i] = $entry
        $i++
    }

    Write-Host ""
    do {
        $resp = Read-Host "Would you like to deactivate one? (Y/N)"
        if ($resp -match '^[Yy]$') {
            break
        } elseif ($resp -match '^[Nn]$') {
            break
        } else {
            Write-Host "Please enter Y or N." -ForegroundColor DarkRed
        }
    } while ($true)
    
    if ($resp -match '^[Yy]$') {
        do {
            do {
                $selection = Read-Host "Enter the number(s) of the role(s) to deactivate (e.g., 1 or 1,2,3)"
                if ($selection -match '^[\d,]+$') {
                    $selectedNumbers = $selection -split ',' | ForEach-Object { $_.Trim() }
                    $validSelections = @()
                    $invalidSelections = @()
                    
                    foreach ($num in $selectedNumbers) {
                        if ($activeMap.ContainsKey([int]$num)) {
                            $validSelections += $activeMap[[int]$num]
                        } else {
                            $invalidSelections += $num
                        }
                    }
                    
                    if ($invalidSelections.Count -gt 0) {
                        Write-Host "Invalid selection(s): $($invalidSelections -join ', ')" -ForegroundColor DarkRed
                        $selection = $null
                    } elseif ($validSelections.Count -eq 0) {
                        Write-Host "No valid selections." -ForegroundColor DarkRed
                        $selection = $null
                    } else {
                        break
                    }
                } else {
                    Write-Host "Invalid format. Use numbers separated by commas (e.g., 1,2,3)" -ForegroundColor DarkRed
                    $selection = $null
                }
            } while (-not $selection)

            Flush-ConsoleInput

            do {
                $justification = Read-Host "Enter justification for deactivation"
                if ([string]::IsNullOrWhiteSpace($justification)) {
                    Write-Host "Justification required." -ForegroundColor DarkRed
                    $justification = $null
                }
            } while (-not $justification)

            $deactivationResults = @()
            $failedDeactivations = @()

            foreach ($toDeactivate in $validSelections) {
                $params = @{
                    Action           = "selfDeactivate"
                    PrincipalId      = $toDeactivate.Assignment.PrincipalId
                    RoleDefinitionId = $toDeactivate.Assignment.RoleDefinitionId
                    DirectoryScopeId = $toDeactivate.Assignment.DirectoryScopeId
                    Justification    = $justification
                    ScheduleInfo     = @{
                        StartDateTime = Get-Date
                    }
                }

                try {
                    $deactivationResult = New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $params -ErrorAction Stop
                    $deactivationResults += $toDeactivate.RoleName
                    Write-Host "✅ Role deactivation submitted for: $($toDeactivate.RoleName)" -ForegroundColor Magenta
                    
                    # Send Teams notification for successful deactivation
                    Send-TeamsNotification -Operation "Deactivation" -UserEmail $context.Account -RoleName $toDeactivate.RoleName -Justification $justification | Out-Null
                } catch {
                    $errorMessage = $_.Exception.Message
                    $cleanErrorMessage = $errorMessage
                    
                    if ($errorMessage -like "*ActiveDurationTooShort*" -or $errorMessage -like "*Active duration is too short*") {
                        $cleanErrorMessage = "Activation too short - Minimum 5 minutes required before deactivation!"
                    } elseif ($errorMessage -like "*JustificationRequired*" -or $errorMessage -like "*justification*") {
                        $cleanErrorMessage = "Justification is required for role deactivation"
                    } elseif ($errorMessage -like "*RoleAssignmentDoesNotExist*") {
                        $cleanErrorMessage = "The role assignment no longer exists"
                    }
                    
                    $failedDeactivations += "$($toDeactivate.RoleName): $cleanErrorMessage"
                }
            }



                            if ($failedDeactivations.Count -gt 0) {
                Write-Host ""
                Write-Host "Failed deactivations:" -ForegroundColor Red
                foreach ($failure in $failedDeactivations) {
                    Write-Host "  $failure" -ForegroundColor Red
                }
            }

            Write-Host ""
            do {
                $continueChoice = Read-Host "Would you like to manage more roles? (Y/N)"
                if ($continueChoice -match '^[Yy]$') {
                    break
                } elseif ($continueChoice -match '^[Nn]$') {
                    Write-Host ""
                    Disconnect-MgGraph | Out-Null
                    Write-Host "Disconnected from Microsoft Graph." -ForegroundColor DarkRed
                    Write-Host ""
                    Write-Host "Press Enter to exit..." -ForegroundColor Cyan
                    $null = Read-Host
                    exit
                } else {
                    Write-Host "Please enter Y or N." -ForegroundColor DarkRed
                }
            } while ($true)

            Write-Host "Refreshing role status..." -ForegroundColor Cyan
            Start-Sleep -Seconds 3  # Give the API more time to reflect the deactivation
            $userAssignments = Get-MgRoleManagementDirectoryRoleAssignment -All | Where-Object { $_.PrincipalId -eq $currentUserId }
            $activeRoles = @()
            foreach ($assignment in $userAssignments) {
                $roleDef = Get-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $assignment.RoleDefinitionId
                $activeRoles += [PSCustomObject]@{
                    Assignment = $assignment
                    RoleName   = $roleDef.DisplayName
                }
            }
            
            # Filter out roles that were just successfully deactivated
            $activeRoles = $activeRoles | Where-Object { $deactivationResults -notcontains $_.RoleName }

            if ($activeRoles.Count -gt 0) {
                Write-Host "You currently have active PIM role(s):" -ForegroundColor Yellow
                $i = 1
                $activeMap = @{}
                foreach ($entry in $activeRoles) {
                    $assignment = $entry.Assignment
                    $scopeDisplay = if ($assignment.DirectoryScopeId -ne "/") { " (Scope: $($assignment.DirectoryScopeId))" } else { "" }
                    Write-Host "[$i] $($entry.RoleName)$scopeDisplay"
                    $activeMap[$i] = $entry
                    $i++
                }

                do {
                    $deactivateAnother = Read-Host "Would you like to deactivate another role? (Y/N)"
                    if ($deactivateAnother -match '^[Yy]$') {
                        break
                    } elseif ($deactivateAnother -match '^[Nn]$') {
                        break
                    } else {
                        Write-Host "Please enter Y or N." -ForegroundColor DarkRed
                    }
                } while ($true)

                if ($deactivateAnother -match '^[Nn]$') {
                    break
                }
            } else {
                Write-Host "No more active roles to deactivate." -ForegroundColor Cyan
                break
            }
        } while ($true)
    }
}

# ========================= 3) Detect Eligible Roles =========================
if ($activeRoles.Count -eq 0) {
    Write-Host "No active roles found. Checking for eligible roles..." -ForegroundColor Cyan
} else {
    Write-Host "Checking for eligible roles..." -ForegroundColor Cyan
}
Write-Host ""

# Use the working logic from PIM-Global.ps1 - simple user-based eligibility detection
$myRoles = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -ExpandProperty RoleDefinition -All -Filter "principalId eq '$currentUserId'"
$validRoles = $myRoles | Where-Object { $_.RoleDefinition -and $_.RoleDefinition.DisplayName }

# Filter out roles that are already active for any principal
$validRoles = $validRoles | Where-Object {
    $roleDefId = $_.RoleDefinitionId
    $principalId = $_.PrincipalId
    
    # Check if this specific role is already active for this specific principal
    try {
        $existing = Get-MgRoleManagementDirectoryRoleAssignment `
            -Filter "principalId eq '$principalId' and roleDefinitionId eq '$roleDefId'"
        return -not $existing
    } catch {
        # If check fails, assume role is not active
        return $true
    }
}

if ($validRoles.Count -eq 0) {
    Write-Host "You do not have any eligible roles for activation." -ForegroundColor DarkRed
    Disconnect-MgGraph | Out-Null
    Write-Host "Disconnected from Microsoft Graph." -ForegroundColor DarkRed
    Write-Host ""
    Write-Host "Press Enter to exit..." -ForegroundColor Cyan
    $null = Read-Host
    exit
}

Write-Host "Available Eligible Roles for Activation:" -ForegroundColor Cyan
Write-Host ""
$index = 1
$roleMap = @{}
foreach ($role in $validRoles) {
    Write-Host ("[{0}] {1}" -f $index, $role.RoleDefinition.DisplayName)
    $roleMap[$index] = $role
    $index++
}

# ========================= 4) Activation Prompt & Submission =========================
do {
    Write-Host ""
    do {
        $selection = Read-Host "Enter the number(s) of the role(s) you want to activate (e.g., 1 or 1,2,3)"
        if ($selection -match '^[\d,]+$') {
            $selectedNumbers = $selection -split ',' | ForEach-Object { $_.Trim() }
            $validSelections = @()
            $invalidSelections = @()
            
            foreach ($num in $selectedNumbers) {
                if ($roleMap.ContainsKey([int]$num)) {
                    $validSelections += $roleMap[[int]$num]
                } else {
                    $invalidSelections += $num
                }
            }
            
            if ($invalidSelections.Count -gt 0) {
                Write-Host "Invalid selection(s): $($invalidSelections -join ', ')" -ForegroundColor DarkRed
                $selection = $null
            } elseif ($validSelections.Count -eq 0) {
                Write-Host "No valid selections." -ForegroundColor DarkRed
                $selection = $null
            } else {
                break
            }
        } else {
            Write-Host "Invalid format. Use numbers separated by commas (e.g., 1,2,3)" -ForegroundColor DarkRed
            $selection = $null
        }
    } while (-not $selection)

    Flush-ConsoleInput

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

    Write-Host ""
    do {
        $justification = Read-Host "Enter reason for activation"
        if ([string]::IsNullOrWhiteSpace($justification)) {
            Write-Host "Justification required." -ForegroundColor DarkRed
            $justification = $null
        }
    } while (-not $justification)

    $activationResults = @()
    $failedActivations = @()
    
    # Collections for batching
    $approvalRequiredRoles = @()
    $immediateActivationRoles = @()
    
    foreach ($myRole in $validSelections) {
        $principalId = $myRole.PrincipalId
        
        try {
            # Check if the role is already active for this specific principal
            $existing = Get-MgRoleManagementDirectoryRoleAssignment `
                -Filter "principalId eq '$principalId' and roleDefinitionId eq '$($myRole.RoleDefinition.Id)'"
            
            if ($existing) {
                $failedActivations += "$($myRole.RoleDefinition.DisplayName): Role is already active for this principal"
                Write-Host "❌ Role activation failed for: $($myRole.RoleDefinition.DisplayName)" -ForegroundColor DarkRed
                Write-Host "  Role is already active for this principal" -ForegroundColor Yellow
                continue
            }
        } catch {
            # Continue if check fails
        }

        $directoryScopeId = if ([string]::IsNullOrEmpty($myRole.DirectoryScopeId)) { "/" } else { $myRole.DirectoryScopeId }

        $params = @{
            Action           = "selfActivate"
            PrincipalId      = $principalId
            RoleDefinitionId = $myRole.RoleDefinition.Id
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
            $activationResult = New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $params -ErrorAction Stop
            $activationResults += $myRole.RoleDefinition.DisplayName
            Write-Host "✅ Role activation submitted for: $($myRole.RoleDefinition.DisplayName)" -ForegroundColor Green
            
            # Calculate expiry time for notification
            $expiry = (Get-Date).Add([System.Xml.XmlConvert]::ToTimeSpan($duration))
            $formattedExpiry = $expiry.ToString("MM/dd/yyyy hh:mm:ss tt")
            
            # Check if the role requires approval by examining the activation result status
            $requiresApproval = $false
            if ($activationResult.Status -eq "PendingApproval" -or $activationResult.Status -eq "PendingAdminDecision") {
                $requiresApproval = $true
            }
            
            # Collect role data for batching
            $roleData = @{
                roleName = $myRole.RoleDefinition.DisplayName
                activationId = $activationResult.Id
                expiryTime = $formattedExpiry
                requiresApproval = $requiresApproval
            }
            
            if ($requiresApproval) {
                $approvalRequiredRoles += $roleData
            } else {
                $immediateActivationRoles += $roleData
                # Send regular activation notification for immediate roles
                Send-TeamsNotification -Operation "Activation" -UserEmail $context.Account -RoleName $myRole.RoleDefinition.DisplayName -Duration $durationInput -Justification $justification -ExpiryTime $formattedExpiry | Out-Null
            }
            
        } catch {
            $errorMessage = $_.Exception.Message
            $cleanErrorMessage = $errorMessage
            
            if ($errorMessage -like "*DurationTooShort*" -or $errorMessage -like "*duration is too short*") {
                $cleanErrorMessage = "Activation too short"
            } elseif ($errorMessage -like "*DurationTooLong*" -or $errorMessage -like "*duration is too long*") {
                $cleanErrorMessage = "The requested activation duration is too long. Maximum allowed duration: 8 hours"
            } elseif ($errorMessage -like "*JustificationRequired*" -or $errorMessage -like "*justification*") {
                $cleanErrorMessage = "Justification is required for role activation"
            } elseif ($errorMessage -like "*AlreadyActive*" -or $errorMessage -like "*already active*") {
                $cleanErrorMessage = "This role is already active for the specified principal"
            }
            
            $failedActivations += "$($myRole.RoleDefinition.DisplayName): $cleanErrorMessage"
        }
    }
    
    # Process batched approvals if enabled
    if ($enableBatchApprovals) {
        # Send batched approval-required roles
        if ($approvalRequiredRoles.Count -gt 0) {
            $trackingId = "PIM-APPROVAL-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$((New-Guid).ToString('N').Substring(0,8))"
            Send-BatchedPowerAutomateApproval -TrackingId $trackingId -UserEmail $context.Account.Trim() -UserDisplayName $currentUser.DisplayName -Roles $approvalRequiredRoles -Duration $durationInput -Justification $justification | Out-Null
        }
        
        # Send batched immediate activation roles for audit
        if ($immediateActivationRoles.Count -gt 0) {
            $trackingId = "PIM-AUDIT-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$((New-Guid).ToString('N').Substring(0,8))"
            Send-BatchedPowerAutomateApproval -TrackingId $trackingId -UserEmail $context.Account.Trim() -UserDisplayName $currentUser.DisplayName -Roles $immediateActivationRoles -Duration $durationInput -Justification $justification | Out-Null
        }
    } else {
        # Fallback to individual requests (original behavior)
        foreach ($roleData in $approvalRequiredRoles) {
            $trackingId = "PIM-APPROVAL-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$((New-Guid).ToString('N').Substring(0,8))"
            Send-PowerAutomateApproval -TrackingId $trackingId -UserEmail $context.Account.Trim() -UserDisplayName $currentUser.DisplayName -RoleName $roleData.roleName -Duration $durationInput -Justification $justification -ActivationId $roleData.activationId -ExpiryTime $roleData.expiryTime | Out-Null
        }
        
        foreach ($roleData in $immediateActivationRoles) {
            $trackingId = "PIM-AUDIT-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$((New-Guid).ToString('N').Substring(0,8))"
            Send-PowerAutomateApproval -TrackingId $trackingId -UserEmail $context.Account.Trim() -UserDisplayName $currentUser.DisplayName -RoleName $roleData.roleName -Duration $durationInput -Justification $justification -ActivationId $roleData.activationId -ExpiryTime $roleData.expiryTime | Out-Null
        }
    }
    
    if ($failedActivations.Count -gt 0) {
        Write-Host ""
        Write-Host "Failed activations:" -ForegroundColor Red
        foreach ($failure in $failedActivations) {
            Write-Host "  $failure" -ForegroundColor Red
        }
    }
    Write-Host ""
    
    # Ask if user wants to activate another role first
    do {
        $activateAnother = Read-Host "Would you like to activate another role? (Y/N)"
        $activateAnother = $activateAnother.Trim()
        if ($activateAnother -match '^[Yy]$') {
            # Only refresh role status after user confirms they want to continue
            Write-Host ""
            Write-Host "Refreshing role status..." -ForegroundColor Cyan
            Start-Sleep -Seconds 2  # Give the API time to reflect the changes
            
            # Refresh active roles
            $userAssignments = Get-MgRoleManagementDirectoryRoleAssignment -All | Where-Object { $_.PrincipalId -eq $currentUserId }
            $activeRoles = @()
            foreach ($assignment in $userAssignments) {
                $roleDef = Get-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $assignment.RoleDefinitionId
                $activeRoles += [PSCustomObject]@{
                    Assignment = $assignment
                    RoleName   = $roleDef.DisplayName
                }
            }
            
            # Refresh eligible roles from API
            $myRoles = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -ExpandProperty RoleDefinition -All -Filter "principalId eq '$currentUserId'"
            
            # Filter out active roles from eligible roles
            $activeRoleIds = if ($activeRoles.Count -gt 0) {
                $activeRoles | ForEach-Object { $_.Assignment.RoleDefinitionId }
            } else {
                @()
            }
            
            # Also filter out roles that were just activated (even if API hasn't updated yet)
            $justActivatedRoleIds = $activationResults | ForEach-Object {
                $roleName = $_
                $myRoles | Where-Object { $_.RoleDefinition.DisplayName -eq $roleName } | Select-Object -ExpandProperty RoleDefinitionId
            }
            
            $validRoles = $myRoles | Where-Object { $_.RoleDefinition -and $_.RoleDefinition.DisplayName }
            $validRoles = $validRoles | Where-Object { 
                $activeRoleIds -notcontains $_.RoleDefinitionId -and 
                $justActivatedRoleIds -notcontains $_.RoleDefinitionId 
            }
            
            if ($validRoles.Count -gt 0) {
                Write-Host ""
                Write-Host "Available Eligible Roles for Activation:" -ForegroundColor Cyan
                Write-Host ""
                $index = 1
                $roleMap = @{}
                foreach ($role in $validRoles) {
                    Write-Host ("[{0}] {1}" -f $index, $role.RoleDefinition.DisplayName)
                    $roleMap[$index] = $role
                    $index++
                }
                # Continue with activation logic
                break
            } else {
                Write-Host "No more eligible roles to activate." -ForegroundColor Cyan
                Write-Host ""
                Disconnect-MgGraph | Out-Null
                Write-Host "Disconnected from Microsoft Graph." -ForegroundColor DarkRed
                Write-Host ""
                Write-Host "Press Enter to exit..." -ForegroundColor Cyan
                $null = Read-Host
                exit
            }
        } elseif ($activateAnother -match '^[Nn]$') {
            Write-Host "Exiting PIM role activation..." -ForegroundColor Yellow
            Disconnect-MgGraph | Out-Null
            Write-Host "Disconnected from Microsoft Graph." -ForegroundColor DarkRed
            Write-Host ""
            Write-Host "Press Enter to exit..." -ForegroundColor Cyan
            $null = Read-Host
            exit
        } else {
            Write-Host "Please enter Y or N." -ForegroundColor DarkRed
        }
        } while ($activateAnother -notmatch '^[YyNn]$')
    } while ($true)

Disconnect-MgGraph | Out-Null
Write-Host "Disconnected from Microsoft Graph." -ForegroundColor DarkRed
Write-Host ""
Write-Host "Press Enter to exit..." -ForegroundColor Cyan
$null = Read-Host
# Nuclear exit - force everything closed
try {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
} catch {}
# Force process termination
[Environment]::Exit(0) 