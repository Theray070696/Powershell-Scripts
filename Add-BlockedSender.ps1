function Add-BlockedSender
{
  <#
    .SYNOPSIS
    Adds a blocked sender address or domain to an Exchange Online spam policy.
    .DESCRIPTION 
    Adds one or more sender email addresses or a single sender domain name 
    to a specified Exchange Online spam policy. Accepts pipeline input or
    comma separated values for the SenderAddress parameter. If the name of
    a spam policy is not specified, assumes the policy name "Default".
    .EXAMPLE
    Read email addresses from a CSV file and pipe the resulting array to 
    the Add-BlockedSender function.
    $spammers = Import-CSV C:\Spammers.csv
    $spammers | Add-BlockedSender
    .EXAMPLE
    Add two email addresses and an email domain to a specified spam policy.
    Add-BlockedSender -SenderAddress "joe@schmoe.com","spammer@123.com" `
      -SenderDomain spammer.com -SpamPolicy "CompanySpamPolicy"
    .PARAMETER SenderAddress
    An email address to add to the blocked senders list.
    .PARAMETER SenderDomain
    An email domain to add to the blocked senders list.
    .PARAMETER SpamPolicy
    The name of an existing spam policy in your Exchange Online 
    organization. Defaults to "Default".
    .NOTES
    This function requires that you have a connection to Exchange Online 
    and have the relevant PowerShell modules loaded.
  #>

  # xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
[CmdletBinding()]
param(
    [Parameter(ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage='Must be one or more valid, comma-separated email addresses.')]
        [string[]]$SenderAddress,
    [Parameter(HelpMessage='Must be one or more valid, comma-separated email domains.')]
        [string]$SenderDomain,
    [Parameter(HelpMessage='The name of an existing Spam Policy in your Exchange Online tenent. Default is Default.')]
        [string]$SpamPolicy = 'Default'
)

    BEGIN
    {
        # Test for connection to Microsoft Online.
        if(-not (Get-Command Get-UnifiedGroup -ea silentlycontinue))
        {
            Write-Warning "This function requires a connection to Office 365. Prompting Now."

            if(-not (Get-Command Connect-ExchangeOnline -ea silentlycontinue))
            {
                Write-Error "Could not find command to connect to Exchange Online."
                Write-Error "Please run Install-Module -Name ExchangeOnlineManagement in an administrator PowerShell window to install the required module."
                $SkipRemainder = $True
            } else
            {
                Connect-ExchangeOnline

                if(-not (Get-Command Get-UnifiedGroup -ea silentlycontinue))
                {
                    Write-Warning "Could not connect to Office 365. Verify credentials and try again later."
                    $SkipRemainder = $True
                }
            }
        }

        # Validate the specified sender domain.
        if($SenderDomain -and ($SenderDomain -notlike "*.*" -or $SenderDomain -like "*@*"))
        {
            Write-Warning "Invalid sender domain"
            $SkipRemainder = $True
        }

        if($SkipRemainder -ne $True)
        {
            # Set a variable for testing the sender addresses later.
            $EmailRegex = '^[=_a-z0-9-]+(\.[_a-z0-9-]+)*@[a-z0-9-]+(\.[a-z0-9-]+)*(\.[a-z]{2,4})$'
        }
    }

    PROCESS
    {
        if($SkipRemainder -ne $True)
        {
            foreach ($Address in $SenderAddress)
            {
                # Validate the sender address parameter.
                if($Address -and ($Address -notmatch $EmailRegex))
                {
                    Write-Warning "Invalid sender address: $Address."
                    $SkipRemainder = $True
                    Return
                }
                # Add the address to the BlockedSenders variable.
                $BlockedSenders += $Address
            }
        }
    }

    END
    {
        if($SkipRemainder -ne $True)
        {
            # Set the new BlockedSenders value.
            if($BlockedSenders)
			{
				Set-HostedContentFilterPolicy -Identity $SpamPolicy -BlockedSenders @{Add=$BlockedSenders}
			}
            # Set the new BlockedSenderDomains value.
            if($SenderDomain)
            {
                $BlockedSenderDomains += $SenderDomain
                Set-HostedContentFilterPolicy -Identity $SpamPolicy -BlockedSenderDomains @{Add=$BlockedSenderDomains}
            }
        }
    }
}
