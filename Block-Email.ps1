######################################################################################################################
# Grabs an email address from an .eml file and blocks it in Office 365.
# Requires Add-BlockedSender.ps1 and Convert-EML.ps1 from https://www.github.com/Theray070696/Powershell-Scripts
# Written by Theray070696. My other scripts can be found at https://www.github.com/Theray070696/Powershell-Scripts
######################################################################################################################

# Set this to where you download .eml files to by default. Will only be checked if no parameter was passed.
$EMLSaveLocation = ""

# Set to your domain to help with detection of spoofed senders
$InternalDomain = ""

# This list contains known mass-hosting domains. Modify this to include any domains you never want to block the domain of. The script will always ask before blocking a domain.
$KnownProviders = @('gmail.com', 'outlook.com', 'hotmail.com', 'pm.me', 'protonmail.com', 'aol.com', 'yahoo.com', 'icloud.com', 'msn.com', 'comcast.net', 'cox.net', 'att.net', 'charter.net', 'mail.com', 'frontiernet.net', 'mac.com')

. .\Add-BlockedSender.ps1
. .\Convert-EML.ps1

function Block-Email
{
    <#
    .SYNOPSIS
        Function will take in an eml file, grab the sender via regex, and block it.

    .DESCRIPTION
        Function will take in an eml file, grab the sender via regex, and block it in Office 365.

    .PARAMETER EmlFileName
        A string representing the eml file to parse.

    .PARAMETER EmlFolder
        A folder containing multiple eml files to parse.

    .PARAMETER SkipDomain
        If included, will not block domain, even if not in known providers list.

    .EXAMPLE
        PS C:\> Block-Email -EmlFileName 'C:\Test\test.eml'

    .OUTPUTS
        System.Object
    #>
    [CmdletBinding()]
    param
    (
        [string]
        $EmlFileName,
        
        [string]
        $EmlFolder,
        
        [switch]
        $SkipDomain
    )
    
    function ConvertEmlAndBlock($FilePath)
    {
        # Convert the EML file to a format we can parse.
        $ConvertedEML = Convert-EmlFile -EmlFileName $FilePath

        # Grab the From property from the converted file.
        $From = Select-Object -InputObject $ConvertedEML -Property From
        
        $Contin = $True

        # Run regex.
        if($From -match '\<([^\<]*)\>')
        {
            # Save the first result to a variable.
            $fromText = $Matches[1]
            
            # Check what the sender domain is, and ask if the user wants to block it if it's not from email providers such as gmail.
            $SenderDomain = $fromText.Split('@')[1]
            $SenderDomain = $SenderDomain.ToLower()
            
            # Sender domain is spoofed, check if Sender property has true sender
            if($SenderDomain -eq $InternalDomain)
            {
                $NewFrom = Select-Object -InputObject $ConvertedEML -Property Sender
                
                if(-not [string]::IsNullOrEmpty($NewFrom))
                {
                    if($NewFrom -match '\<([^\<]*)\>')
                    {
                        $newFromText = $Matches[1]
                        
                        $NewSenderDomain = $newFromText.Split('@')[1]
                        $NewSenderDomain = $NewSenderDomain.ToLower()
                        
                        if($NewSenderDomain -ne $SenderDomain)
                        {
                            Write-Host "From field was spoofed, found sender in Sender field. Pay attention when blocking!"
                            Write-Host "From field was $fromText, Sender field was $newFromText"
                            $From = $NewFrom
                            $fromText = $newFromText
                            $SenderDomain = $NewSenderDomain
                        }
                    }
                } else
                {
                    Write-Host "Sender domain matches internal domain! Sender is either spoofed or compromised!"
                }
            }

            Write-Host "Email Address is $fromText."
        
            # Loop through every field in the converted EML file
            ForEach($Property in $ConvertedEML.Fields)
            {
                # Look for received-spf field
                if($Property.Name -eq 'urn:schemas:mailheader:received-spf' -and $Contin) 
                {
                    # Convert to lowercase to make life easier
                    $LowerValue = $Property.Value.ToLower()
                    
                    # Check if SPF has failed or softfailed. If it has, the from field has likely been spoofed
                    if($LowerValue.Contains('fail') -or $LowerValue.Contains('softfail')) # Yes the second is redundant, but it makes me feel better
                    {
                        # It failed or softfailed, inform user of risk and ask if we should continue
                        $ConfirmationSpoof = Read-Host 'Sender has been spoofed! Continuing may block a legitimate user in your organization! Do you wish to continue? [y/N]'
                        
                        if($ConfirmationSpoof.ToLower() -ne 'y')
                        {
                            # User does not want to continue, ask if we should delete the EML file
                            $ConfirmationDelete = Read-Host 'Aborting, should we delete the EML file? [y/N]'
                            
                            if($ConfirmationDelete.ToLower() -eq 'y')
                            {
                                # Remove the EML File so it's not grabbed next time.
                                Remove-Item $FilePath
                            }
                            
                            # Exit this function
                            return
                        }
                        
                        $Contin = $False
                    }
                } elseif($Property.Name -eq 'urn:schemas:mailheader:authentication-results' -and $Contin)
                {
                    # Convert to lowercase to make life easier
                    $LowerValue = $Property.Value.ToLower()
                    
                    # Check if SPF, DKIM or DMARC has failed or softfailed. If it has, the from field has likely been spoofed
                    if($LowerValue.Contains('spf=fail') -or $LowerValue.Contains('spf=softfail') -or $LowerValue.Contains('dkim=fail') -or $LowerValue.Contains('dmarc=fail') -or $LowerValue.Contains('compauth=fail'))
                    {
                        # It failed or softfailed, inform user of risk and ask if we should continue
                        $ConfirmationSpoof = Read-Host 'Sender has been spoofed! Continuing may block a legitimate user in your organization! Do you wish to continue? [y/N]'
                        
                        if($ConfirmationSpoof.ToLower() -ne 'y')
                        {
                            # User does not want to continue, ask if we should delete the EML file
                            $ConfirmationDelete = Read-Host 'Aborting, should we delete the EML file? [y/N]'
                            
                            if($ConfirmationDelete.ToLower() -eq 'y')
                            {
                                # Remove the EML File so it's not grabbed next time.
                                Remove-Item $FilePath
                            }
                            
                            # Exit this function
                            return
                        }
                        
                        $Contin = $False
                    }
                }
            }

            # Block the sender in Office 365
            Add-BlockedSender -SenderAddress $fromText

            Write-Host "Blocked $fromText."
            
            if(-not ($KnownProviders -contains $SenderDomain) -and -not $SkipDomain)
            {
                $ConfirmationDomain = Read-Host "Email domain $SenderDomain is not in known common email provider list, recommend blocking it if it's not recognized. Block? [y/N]"
                
                if($ConfirmationDomain.ToLower() -eq 'y')
                {
                    Write-Host "Blocking $SenderDomain."
                    
                    Add-BlockedSender -SenderDomain $SenderDomain
                    
                    Write-Host "Blocked $SenderDomain."
                }
            }

            # Remove the EML File so it's not grabbed next time.
            Remove-Item $FilePath
        }
    }

    if([string]::IsNullOrEmpty($EmlFileName))
    {
        if(Test-Path $EMLSaveLocation)
        {
            $EmlFileName = $EMLSaveLocation
        }
    }
    
    if(![string]::IsNullOrEmpty($EmlFolder) -and [string]::IsNullOrEmpty($EmlFileName))
    {
        # We got a folder, loop through all the Eml files.
        $EmlFiles = Get-ChildItem -Path $EmlFolder -Filter *.eml -File
        
        ForEach($EmlFile in $EmlFiles)
        {
            ConvertEmlAndBlock $EmlFile
        }
        return
    }

    if([string]::IsNullOrEmpty($EmlFileName))
    {
        Write-Host "File not specified, terminating."
        return
    }
    
    ConvertEmlAndBlock $EmlFileName
}
