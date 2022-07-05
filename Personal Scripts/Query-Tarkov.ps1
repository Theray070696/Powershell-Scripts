######################################################################################################################
# Queries tarkov.dev API to check if a given item is needed for a task or hideout upgrade.
# Should be faster than using the web page, as no images are transferred.
# Written by Theray070696. My other scripts can be found at https://www.github.com/Theray070696/Powershell-Scripts
######################################################################################################################

[cmdletbinding()]
Param()

$API = 'https://api.tarkov.dev/graphql'

$HideoutQuery = "{ `"query`": `"{ hideoutStations { name levels { level itemRequirements { item { name } } } } }`" }"

$MatchingUpgrades = [System.Collections.ArrayList]@()
Function Check-Hideout($Name)
{
    $LowerName = $Name.ToLower()
    
    ForEach($Station in $HideoutResponseObj.data.hideoutStations)
    {
        $StationName = $Station.name
        ForEach($Level in $Station.levels)
        {
            $LevelNum = $Level.level
            ForEach($ItemRequirement in $Level.itemRequirements)
            {
                if($ItemRequirement.item.name.ToLower() -eq $LowerName)
                {
                    Write-Verbose "Found match in $StationName $LevelNum"
                    $null = $MatchingUpgrades.Add("$StationName $LevelNum")
                    break
                }
            }
        }
    }
}

Function Check-VendorPrice($ItemResponseObject)
{
    $HighestPrice = 0
    $Seller = ''
    
    ForEach($Sell in $ItemResponseObj.data.itemsByName[0].sellFor)
    {
        if($Sell.vendor.name.ToLower() -eq 'flea market')
        {
            continue
        }
        
        if($Sell.price -gt $HighestPrice)
        {
            $HighestPrice = $Sell.price
            $Seller = $Sell.vendor.name
            Write-Verbose "Current highest seller: $Seller for $HighestPrice"
        }
    }

    if($HighestPrice -gt 0)
    {
        Write-Verbose "$Seller for $HighestPrice"
        return "$Seller for $HighestPrice"
    }

    return ''
}

Write-Verbose 'Querying hideout data...'

$HideoutResponse = Invoke-WebRequest -Uri $API -Method 'POST' -ContentType 'application/json' -Body $HideoutQuery

$HideoutOK = $true

if($HideoutResponse.StatusDescription -eq "OK")
{
    $HideoutResponseObj = ConvertFrom-Json $HideoutResponse
} else
{
    $HideoutOK = $false
}

if(-not $HideoutOK)
{
    Write-Host 'Could not retreive hideout info, will not be able to provide anything related to hideout'
} else
{
    Write-Verbose 'Hideout OK!'
}

while($true)
{
    $ItemNameInput = Read-Host "Enter part of the item name you're checking or type 'exit' to exit"
    
    if([string]::IsNullOrEmpty($ItemNameInput))
    {
        Write-Error 'Invalid input'
        continue
    }
    
    if($ItemNameInput.ToLower() -eq 'exit' -or $ItemNameInput.ToLower() -eq 'quit')
    {
        Write-Verbose 'Exiting'
        return
    }

    $ItemQuery = "{ `"query`": `"{ itemsByName(name: \`"$ItemNameInput\`") { name shortName id usedInTasks { name } sellFor { vendor { name } price } } }`" }"

    Write-Verbose "Query: $ItemQuery"

    $ItemResponse = Invoke-WebRequest -Uri $API -Method 'POST' -ContentType 'application/json' -Body $ItemQuery

    if($ItemResponse.StatusDescription -eq "OK")
    {
        $ItemResponseObj = ConvertFrom-Json $ItemResponse
        if(-not [string]::IsNullOrEmpty($ItemResponseObj.data.itemsByName[0].name))
        {
            $ItemName = $ItemResponseObj.data.itemsByName[0].name
            if($HideoutOK)
            {
                Write-Verbose "Searching hideout stations for $ItemName"
                $MatchingUpgrades = [System.Collections.ArrayList]@()
                Check-Hideout($ItemName)
            }
            
            if(-not [string]::IsNullOrEmpty($ItemResponseObj.data.itemsByName[0].usedInTasks.Name))
            {
                Write-Host "$ItemName is used in the following tasks: $($ItemResponseObj.data.itemsByName[0].usedInTasks.Name -join ', ')"
                
                if($HideoutOK -and $MatchingUpgrades.Length -gt 0)
                {
                    Write-Host "$ItemName is also used by the following hideout upgrades: $($MatchingUpgrades -join ', ')"
                }
            } elseif($HideoutOK -and $MatchingUpgrades.Length -gt 0)
            {
                Write-Host "$ItemName is used in the following hideout upgrades: $($MatchingUpgrades -join ', ')"
            } elseif($HideoutOK)
            {
                Write-Host "$ItemName is not used in any tasks or hideout upgrades"
            } else
            {
                Write-Host "$ItemName is not used in any tasks"
            }
            
            $SellsFor = Check-VendorPrice($ItemResponseObj)

            if(-not [string]::IsNullOrEmpty($SellsFor))
            {
                Write-Host "$ItemName sells best at $SellsFor"
            }
        } else
        {
            Write-Host "$ItemNameInput was not found"
        }
    }
}
