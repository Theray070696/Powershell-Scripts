######################################################################################################################
# Syncs down specified sites from SharePoint.
# Written by Theray070696. My other scripts can be found at https://www.github.com/Theray070696/Powershell-Scripts
######################################################################################################################

param(
    [switch]$Silent
)

### VARIABLE - CHANGE THIS
$Company = "" # Name of company in SharePoint, can be pulled from https://admin.microsoft.com/#/Settings/OrganizationProfile/:/Settings/L1/OrganizationInformation under Name
###

$Version = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name ReleaseID | Select-Object ReleaseID
if($version.releaseID -lt 1709) { return }

function DisplaySignInGUI()
{
    if($Silent)
    {
        return
    }
    
    Add-Type -Assembly System.Windows.Forms

    $main_form = New-Object System.Windows.Forms.Form

    $main_form.Text = "Sign into OneDrive"
    $main_form.Width = 30
    $main_form.Height = 40
    $main_form.AutoSize = $true
    
    $Label = New-Object System.Windows.Forms.Label
    $Label.Text = "Please sign into OneDrive, then click the button."
    $Label.Location = New-Object System.Drawing.Point(0, 8)
    $Label.AutoSize = $true
    $main_form.Controls.Add($Label)
    
    $OK_Button = New-Object System.Windows.Forms.Button
    $OK_Button.Location = New-Object System.Drawing.Size(275, 5)
    $OK_Button.Size = New-Object System.Drawing.Size(60, 23)
    $OK_Button.Text = "I signed in"
    $main_form.Controls.Add($OK_Button)

    $OK_Button.Add_Click(
    {
        $main_form.Close()
    })

    if((Get-Process -Name OneDrive -ErrorAction SilentlyContinue))
    {
        Write-Host "OneDrive open, killing."

        Stop-Process -Name "OneDrive"
        
        sleep -Seconds 1 # Sleep is required, if the same script runs at the same time it'll mess up the configuration.
    }

    Write-Host "Starting OneDrive."

    start "odopen://launch?useremail=$UPN"

    Write-Host "Displaying sign-in confirmation box."
    
    $main_form.ShowDialog()
}

function DisplaySetupCompleteGUI()
{
    if($Silent)
    {
        return
    }
    
    Add-Type -Assembly System.Windows.Forms

    $main_form = New-Object System.Windows.Forms.Form

    $main_form.Text = "OneDrive Setup Complete"
    $main_form.Width = 20
    $main_form.Height = 40
    $main_form.AutoSize = $true
    
    $Label = New-Object System.Windows.Forms.Label
    $Label.Text = "OneDrive User Setup Complete!"
    $Label.Location = New-Object System.Drawing.Point(0, 8)
    $Label.AutoSize = $true
    $main_form.Controls.Add($Label)
    
    $OK_Button = New-Object System.Windows.Forms.Button
    $OK_Button.Location = New-Object System.Drawing.Size(200, 5)
    $OK_Button.Size = New-Object System.Drawing.Size(60, 23)
    $OK_Button.Text = "OK"
    $main_form.Controls.Add($OK_Button)

    $OK_Button.Add_Click(
    {
        $main_form.Close()
    })
    
    $main_form.ShowDialog()
}

function SyncFolder()
{
    $path = "$($env:userprofile)\$Company\$webtitle - $listtitle"
    
    if(Test-Path $path)
    {
        Write-Host "Folder $webtitle - $listtitle exists, skipping."
        return
    }

    if((Get-Process -Name OneDrive -ErrorAction SilentlyContinue))
    {
        Write-Host "OneDrive open, killing."

        Stop-Process -Name "OneDrive"
        
        sleep -Seconds 1 # Sleep is required, if the same script runs at the same time it'll mess up the configuration.

        Write-Host "Starting OneDrive."

        start "C:\Program Files\Microsoft OneDrive\OneDrive.exe"

        sleep -Seconds 5
    }
    
    Write-Host "Syncing to $path"

    start "odopen://sync/?siteId=$siteid&webId=$webid&listId=$listid&userEmail=$upn&webUrl=$URL&webtitle=$webtitle&listtitle=$listtitle"
    
    sleep -Seconds 3 # Sleep is required, if the same script runs at the same time it'll mess up the configuration.

    if(-not (Test-Path $path))
    {
        sleep -Seconds 7
    }
}

$UPN = whoami /upn

if(-not (Test-Path "HKCU:\SOFTWARE\Microsoft\OneDrive\Accounts\Business1\UserEmail")) # This regsitry key is blank when not signed into OneDrive
{
    DisplaySignInGUI
}

if(-not $Silent)
{
    Start-Process -NoNewWindow -FilePath 'powershell.exe' {
        Add-Type -Assembly System.Windows.Forms

        $progress_form = New-Object System.Windows.Forms.Form

        $progress_form.Text = 'OneDrive Setup in Progress'
        $progress_form.Width = 30
        $progress_form.Height = 40
        $progress_form.AutoSize = $true

        $Label2 = New-Object System.Windows.Forms.Label
        $Label2.Text = 'OneDrive is being set up. This may take several minutes.'
        $Label2.Location = New-Object System.Drawing.Point(0, 8)
        $Label2.AutoSize = $true
        $progress_form.Controls.Add($Label2)

        $OK_Button2 = New-Object System.Windows.Forms.Button
        $OK_Button2.Location = New-Object System.Drawing.Size(300, 5)
        $OK_Button2.Size = New-Object System.Drawing.Size(60, 23)
        $OK_Button2.Text = 'OK'
        $progress_form.Controls.Add($OK_Button2)

        $OK_Button2.Add_Click(
        {
            $progress_form.Close()
        })

        $progress_form.ShowDialog()
    }
}

# Copy from HERE

# These values must be filled in. How you find each is here: https://learn.microsoft.com/en-us/sharepoint/deploy-on-windows OR start a manual sync, cancel it, the click Copy Library ID. This gets you everything you need.
$siteid = "" # https://<TenantName>.sharepoint.com/sites/<SiteName>/_api/site/id
$webid = "" # https://<TenantName>.sharepoint.com/sites/<SiteName>/_api/web/id
$listid = "" # https://<tenant>.sharepoint.com/sites/<SiteName>/_layouts/15/listedit.aspx?List=%7Bxxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx%7D
$URL = "" # https://<TenantName>.sharepoint.com/sites/<SiteName>/_api/web/url
$webtitle = "" # First half of local folder name
$listtitle = "" # Second half of local folder name

SyncFolder # To HERE


if((Get-Process -Name OneDrive -ErrorAction SilentlyContinue))
{
    sleep -Seconds 3
    
    Write-Host "OneDrive open, killing."

    Stop-Process -Name "OneDrive"
    
    sleep -Seconds 1 # Sleep is required, if the same script runs at the same time it'll mess up the configuration.

    Write-Host "Starting OneDrive."

    start "C:\Program Files\Microsoft OneDrive\OneDrive.exe"
}

DisplaySetupCompleteGUI
