######################################################################################################################
# Saves permissions of folders in specified root folder and optionally subfolders to CSV file specified.
# Written by Theray070696. My other scripts can be found at https://www.github.com/Theray070696/Powershell-Scripts
######################################################################################################################

[CMDLetBinding()]
param(
    [Parameter(Mandatory=$True, HelpMessage='The domain of your SharePoint site. IE contoso')]
    [string]$Domain,
    [Parameter(Mandatory=$True, HelpMessage='The output CSV file.')]
    [string]$ReportFile,
    [Parameter(Mandatory=$True, HelpMessage="The relative folder URL in SharePoint. IE if your folder is in the Administration site in the Finance folder, you`'ll enter Administration/Finance")]
    $FolderRelativeURL,
    [Parameter(HelpMessage='Whether or not to check subfolders.')]
    [switch]$Recurse,
    [Parameter(HelpMessage='Whether or not to include limited access permissions (normally your tenant).')]
    [switch]$IncludeLimited,
    [Parameter(HelpMessage='The maximum folder depth this script will go to.')]
    [int]$MaxDepth,
    [Parameter(HelpMessage='Whether or not to include the SYSTEM user.')]
    [switch]$IncludeSystem
)

$PermissionCollection = New-Object System.Collections.Generic.List[System.Object]

# Might not be a bad idea to move these to parameters. I'll do it later.
$SiteURL="https://$Domain.sharepoint.com/"

# The following function if slightly modified from the one that can be found at https://www.sharepointdiary.com/2018/03/sharepoint-online-powershell-to-get-folder-permissions.html
#Function to Get Permissions Applied on a particular Object such as: Web, List, Library, Folder or List Item
Function Get-PnPPermissions([Microsoft.SharePoint.Client.SecurableObject]$Object, $FolderName)
{
    Try
    {
        #Get permissions assigned to the Folder
        Get-PnPProperty -ClientObject $Object -Property HasUniqueRoleAssignments, RoleAssignments
         
        #Check if Object has unique permissions
        $HasUniquePermissions = $Object.HasUniqueRoleAssignments

        Write-Verbose "$FolderName Has Unique Permissions $HasUniquePermissions"
        
        #Loop through each permission assigned and extract details
        Foreach($RoleAssignment in $Object.RoleAssignments)
        {
            #Get the Permission Levels assigned and Member
            Get-PnPProperty -ClientObject $RoleAssignment -Property RoleDefinitionBindings, Member
            
            #Get the Principal Type: User, SP Group, AD Group
            $PermissionType = $RoleAssignment.Member.PrincipalType
            $PermissionLevels = $RoleAssignment.RoleDefinitionBindings | Select -ExpandProperty Name
            
            if(-Not $IncludeLimited)
            {
                #Remove Limited Access
                #$PermissionLevels = ($PermissionLevels | Where { $_ –ne "Limited Access"}) -join ","
                #$PermissionLevels = ($PermissionLevels | Where { $_ –ne "System.LimitedEdit"}) -join "," # I think this is what the above is trying to acomplish, but I need to double check
                $PermissionLevels = ($PermissionLevels | Where { $_ –ne "Limited Access"} | Where { $_ –ne "System.LimitedEdit"}) -join ","
                If($PermissionLevels.Length -eq 0) {Continue}
            }
         
            #Get SharePoint group members
            If($PermissionType -eq "SharePointGroup")
            {
                #Get Group Members
                $GroupMembers = Get-PnPGroupMember -Group $RoleAssignment.Member.LoginName
                
                #Leave Empty Groups
                If($GroupMembers.count -eq 0){Continue}

                Write-Host "Test"
                
                ForEach($User in $GroupMembers)
                {
                    if(-Not $IncludeSystem -And $PermissionType -eq "User" -And $User.Title -eq "System Account")
                    {
                        continue
                    }
                    
                    #Add the Data to Object
                    $Permissions = New-Object PSObject
                    $Permissions | Add-Member NoteProperty Folder($FolderName)
                    $Permissions | Add-Member NoteProperty User($User.Title)
                    $Permissions | Add-Member NoteProperty Type($PermissionType)
                    $Permissions | Add-Member NoteProperty Permissions($PermissionLevels)
                    $Permissions | Add-Member NoteProperty GrantedThrough("SharePoint Group: $($RoleAssignment.Member.LoginName)")
                    
                    $PermissionCollection.Add($Permissions)
                    
                    Write-Verbose "Added to PermissionCollection: Folder: $FolderName User: $($User.Title) Type: $PermissionType Permissions: $PermissionLevels GrantedThrough: $($RoleAssignment.Member.LoginName)"
                }
            } else
            {
                if(-Not $IncludeSystem -And $PermissionType -eq "User" -And $RoleAssignment.Member.Title -eq "System Account")
                {
                    continue
                }
                    
                #Add the Data to Object
                $Permissions = New-Object PSObject
                $Permissions | Add-Member NoteProperty Folder($FolderName)
                $Permissions | Add-Member NoteProperty User($RoleAssignment.Member.Title)
                $Permissions | Add-Member NoteProperty Type($PermissionType)
                $Permissions | Add-Member NoteProperty Permissions($PermissionLevels)
                $Permissions | Add-Member NoteProperty GrantedThrough("Direct Permissions")

                $PermissionCollection.Add($Permissions)

                Write-Verbose "Added to PermissionCollection: Folder: $FolderName User: $($RoleAssignment.Member.Title) Type: $PermissionType Permissions: $PermissionLevels GrantedThrough: $($RoleAssignment.Member.LoginName)"
            }
        }
    } Catch
    {
        Write-Host -f Red "Error Generating Folder Permission Report!" $_.Exception.Message
    }

    Write-Verbose "Current PermissionCollection count: $($PermissionCollection.Count)"
}

# The following function if slightly modified from the one that can be found at https://www.c-sharpcorner.com/blogs/how-to-get-all-the-folders-and-subfolders-from-sharepoint-online-document-library-using-pnp-powershell
# Loop through to get all the folders and subfolders and get permissions for each folder
Function Get-FolderPermissions($rootFolderUrl, $CurrentDepth)
{
    $CurrentDepth += 1

    if($Recurse -And $MaxDepth -gt 0 -And $CurrentDepth -gt $MaxDepth)
    {
        Write-Verbose "Hit depth limit at folder $rootFolderUrl"
        return
    }
    
    $folderColl = Get-PnPFolderItem -FolderSiteRelativeUrl $rootFolderUrl -ItemType Folder
    # Loop through the folders  
    foreach($folder in $folderColl)
    {
        $newFolderURL= $($rootFolderUrl + "/" + $folder.Name).TrimEnd('/')

        Write-Verbose "Previous Folder: $($folder.Name) Current Folder: $newFolderURL"

        Get-PnPPermissions $(Get-PnPFolder -Url $newFolderURL).ListItemAllFields $newFolderURL

        if($Recurse)
        {
            Write-Verbose "Current depth: $CurrentDepth"

            # Call the function to get the folders inside folder
            Get-FolderPermissions $newFolderURL $CurrentDepth
        }
    }
}

#Connect to the Site collection
Connect-PnPOnline -URL $SiteURL -UseWebLogin

Get-FolderPermissions $FolderRelativeURL 0

If($PermissionCollection.Count -gt 0)
{
    #Export Permissions to CSV File
    $PermissionCollection | Export-CSV $ReportFile -NoTypeInformation
    Write-Host -f Green "`n*** Folder Permission Report Generated Successfully!***" # Yeah this could be better tbh, but fuggit
} else
{
    Write-Host -f Red "Error Generating Folder Permission Report!"
}
