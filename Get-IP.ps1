######################################################################################################################
# Gets IP address that starts with specific number from adapters and returns that as the exit code. Useful for FOG.
# Written by Theray070696. My other scripts can be found at https://www.github.com/Theray070696/Powershell-Scripts
######################################################################################################################

$IPStartsWith = "192.168" # Replace this with what you expect the IP to start with, could be an argument tbh.

$IPs = Get-NetIPAddress # Get all adapters

ForEach($IP in $IPs) # Loop through them
{
    if($IP.IPAddress.StartsWith($IPStartsWith)) # Make sure the IP starts with what was entered above
    {
        $IPAddress = $IP.IPAddress -replace "\.(?=.*)" # Remove the dots via RegEx
        exit $IPAddress # Return code
    }
}
