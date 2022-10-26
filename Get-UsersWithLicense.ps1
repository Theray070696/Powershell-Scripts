######################################################################################################################
# Searches AzureAD users for a specific license, and exports it to a CSV file.
# Written by Theray070696. My other scripts can be found at https://www.github.com/Theray070696/Powershell-Scripts
######################################################################################################################

If($PSVersionTable.PSVersion.Major -eq 7)
{
    Write-Error "This script is incompatible with PowerShell 7, and is only verified to work currently on PowerShell 5."
    return
} Else
{
    If([Microsoft.Open.Azure.AD.CommonLibrary.AzureSession]::AccessTokens -eq $null -or [Microsoft.Open.Azure.AD.CommonLibrary.AzureSession]::AccessTokens.Count -eq 0)
    {
        Write-Warning "This function requires a connection to AzureAD. Prompting Now."
	
	Import-Module AzureAD
      
        If(-Not (Get-Command Connect-AzureAD -ea SilentlyContinue))
        {
            Write-Error "Could not find command to connect to AzureAD."
            Write-Error "Please run Install-Module -Name AzureAD in an administrator PowerShell window to install the required module."
            return
        } Else
        {
            Connect-AzureAD
        
            If([Microsoft.Open.Azure.AD.CommonLibrary.AzureSession]::AccessTokens -eq $null -or [Microsoft.Open.Azure.AD.CommonLibrary.AzureSession]::AccessTokens.Count -eq 0)
            {
                Write-Warning "Could not connect to AzureAD. Verify credentials and try again later."
                return
            }
        }
    }
}

Write-Host 'Getting licenses...'

$Licenses = (Get-AzureADSubscribedSku).SkuPartNumber
$LicenseSkuIds = (Get-AzureADSubscribedSku).SkuId

$Index = 0

ForEach($License in $Licenses)
{
	Write-Host "$Index ----- $License"
	$Index = $Index + 1
}

$SelectedIndex = [int](Read-Host 'Input what License Index should be searched for')

$SelectedSkuId = $LicenseSkuIds[$SelectedIndex]

Write-Host 'Getting all users, this may take a moment...'

$Users = Get-AzureADUser -All:$True

Write-Host "Looping through $($Users.Count) users to check licenses..."

$UsersWithLicense = @()

ForEach($User in $Users)
{
	$AssignedLicenses = $User.AssignedLicenses
	
	ForEach($AssignedLicense in $AssignedLicenses)
	{
		if($AssignedLicense.SkuId -eq $SelectedSkuId)
		{
			$UsersWithLicense += $User
			break
		}
	}
}

Write-Host "Looping complete! $($UsersWithLicense.Count) users found that had a matching license assigned."

if($UsersWithLicense.Count -gt 0)
{
	$Destination = Read-Host 'Where should the CSV file with matching users go?'
	$UsersWithLicense | Select-Object DisplayName,UserPrincipalName,AccountEnabled | Export-CSV -Path $Destination -NoTypeInformation
}
