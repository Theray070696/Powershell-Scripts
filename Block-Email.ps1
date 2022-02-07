######################################################################################################################
# Grabs an email address from an .eml file and blocks it in Office 365.
# Requires Add-BlockedSender.ps1 and Convert-EML.ps1 from https://www.github.com/Theray070696/Powershell-Scripts
# Written by Theray070696. My other scripts can be found at https://www.github.com/Theray070696/Powershell-Scripts
######################################################################################################################

# Set this to where you download .eml files to by default. Will only be checked if no parameter was passed.
$EMLSaveLocation = ""

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

    .EXAMPLE
        PS C:\> Block-Email -EmlFileName 'C:\Test\test.eml'

    .OUTPUTS
        System.Object
    #>
    [CmdletBinding()]
    param
    (
        [ValidateNotNullOrEmpty()]
        [string]
        $EmlFileName
    )

    if([string]::IsNullOrEmpty($EmlFileName))
    {
        if(Test-Path $EMLSaveLocation)
        {
            $EmlFileName = $EMLSaveLocation
        }
    }

    if([string]::IsNullOrEmpty($EmlFileName))
    {
        Write-Host "File not specified, terminating."
        return
    }
    
    # Convert the EML file to a format we can parse.
    $ConvertedEML = Convert-EmlFile -EmlFileName $EmlFileName

    # Grab the From property from the converted file.
    $From = Select-Object -InputObject $ConvertedEML -Property From

    # Run regex.
    if($From -match '\<([^\<]*)\>')
    {
        # Save the first result to a variable.
        $fromText = $Matches[1]

        Write-Host Email Address is $fromText.

        # Block the sender in Office 365
        Add-BlockedSender -SenderAddress $fromText

        Write-Host Blocked $fromText.

        # Remove the EML File so it's not grabbed next time.
        Remove-Item $EmlFileName
    }
}
