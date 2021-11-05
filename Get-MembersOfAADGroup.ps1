######################################################################################################################
# Saves membership of all matching groups in AzureAD to CSV file specified.
# Written by Theray070696. My other scripts can be found at https://www.github.com/Theray070696/Powershell-Scripts
######################################################################################################################

[CMDLetBinding()]
param(
    [Parameter(Mandatory=$True, HelpMessage='The full or partial name of the group you want the members of.')]
    [string]$GroupName,
    [Parameter(Mandatory=$True, HelpMessage='The path to the output CSV.')]
    [string]$Output
)

If($PSVersionTable.PSVersion.Major -eq 7)
{
    Write-Error "This script is incompatible with PowerShell 7, and is only verified to work currently on PowerShell 5."
    $SkipRemainder = $True
} Else
{
    If(-Not (Get-Command Get-AzureADGroup -ea SilentlyContinue))
    {
        Write-Warning "This function requires a connection to AzureAD. Prompting Now."
	  
        If(-Not (Get-Command Connect-AzureAD -ea SilentlyContinue))
        {
            Write-Error "Could not find command to connect to AzureAD."
            Write-Error "Please run Install-Module -Name AzureAD in an administrator PowerShell window to install the required module."
            $SkipRemainder = $True
        } Else
        {
            Connect-AzureAD
		
            If(-not (Get-Command Get-AzureADGroup -ea SilentlyContinue))
            {
  	            Write-Warning "Could not connect to AzureAD. Verify credentials and try again later."
                $SkipRemainder = $True
            }
        }
    }
}

If($SkipRemainder -ne $True)
{
    $MemberCollection = New-Object System.Collections.Generic.List[System.Object]

    ForEach($Group in Get-AzureADGroup -SearchString $GroupName)
    {
        Write-Verbose "Group name: $($Group.DisplayName)"
        
        $GroupMembers = Get-AzureADGroupMember -ObjectId $Group.ObjectId
        
        ForEach($Member in $GroupMembers)
        {
            $Mem = New-Object PSObject
            $Mem | Add-Member NoteProperty GroupName($Group.DisplayName)
            $Mem | Add-Member NoteProperty DisplayName($Member.DisplayName)
            $Mem | Add-Member NoteProperty UserPrincipalName($Member.UserPrincipalName)
            $Mem | Add-Member NoteProperty UserType($Member.UserType)

            $MemberCollection.Add($Mem)

            Write-Verbose "Added to MemberCollection: GroupName: $($Group.DisplayName) ObjectId: $($Member.ObjectId) DisplayName: $($Member.DisplayName) UserPrincipalName: $($Member.UserPrincipalName) UserType: $($Member.UserType)"
        }
    }

    If($MemberCollection.Count -gt 0)
    {
        $MemberCollection | Export-CSV $Output -NoTypeInformation
        Write-Host -f Green "`n*** Folder Permission Report Generated Successfully!***"
    } Else
    {
        Write-Host -f Red "Error Generating User Membership Report!"
    }
}