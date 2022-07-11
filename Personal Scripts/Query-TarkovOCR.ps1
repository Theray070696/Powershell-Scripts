######################################################################################################################
# Uses Tesseract OCR to grab hovered item name, then query tarkov.dev when the Pause/Break key is pressed
# Requires Tesseract OCR to be installed and on PATH
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
    
    $i = 0
    ForEach($Station in $HideoutResponseObj.data.hideoutStations)
    {
        $i++
        $PC = $($i / $HideoutResponseObj.data.hideoutStations.Length) * 100
        Write-Progress -Activity 'Hideout Search' -Status 'Searching...' -PercentComplete $PC
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
    Write-Progress -Activity 'Hideout Search' -Completed
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
        $SellPrice = $HighestPrice
        Write-Verbose "$Seller for $HighestPrice"
        return [PSCustomObject] @{
            Vendor = $Seller
            Price = $HighestPrice
        }
    }

    return $null
}

Function Query-TarkovDB($InputItem)
{
    $ItemQuery = "{ `"query`": `"{ itemsByName(name: \`"$InputItem\`") { name shortName id width height usedInTasks { name } sellFor { vendor { name } price } } }`" }"

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
            
            $SellData = Check-VendorPrice($ItemResponseObj)

            if($SellData -ne $Null)
            {
                Write-Host "$ItemName sells best at $($SellData.Vendor) for $($SellData.Price)"

                Write-Verbose "Item size is width $($ItemResponseObj.data.itemsByName[0].width) height $($ItemResponseObj.data.itemsByName[0].height), total size $($ItemResponseObj.data.itemsByName[0].width * $ItemResponseObj.data.itemsByName[0].height) slots"

                $TotalSlots = $ItemResponseObj.data.itemsByName[0].width * $ItemResponseObj.data.itemsByName[0].height

                Write-Host "Value per slot is $($SellData.Price / $TotalSlots)"
            }
        } else
        {
            Write-Host "$InputItem was not found"
        }
    }
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








Add-Type -AssemblyName System.Windows.Forms
Add-type -AssemblyName System.Drawing

Function Get-CursorPos()
{
    $X = [System.Windows.Forms.Cursor]::Position.X
    $Y = [System.Windows.Forms.Cursor]::Position.Y

    Write-Verbose "X: $X | Y: $Y"

    return [PSCustomObject] @{
        X = $X
        Y = $Y
    }
}

Function PauseBreakDown()
{
    # valid key names can be ASCII codes:
    $key = '19'
    
    # this is the c# definition of a static Windows API method:
    $Signature = @'
    [DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)]
    public static extern short GetAsyncKeyState(int virtualKeyCode);
'@
    
    # Add-Type compiles the source code and adds the type [PsOneApi.Keyboard]:
    Add-Type -MemberDefinition $Signature -Name Keyboard -Namespace PsOneApi
    
    return [bool]([PsOneApi.Keyboard]::GetAsyncKeyState($key) -eq -32767)
}

Function GetImageText($ImageFile)
{
    $OutputFile = "$($(Get-Item $ImageFile).Directory.FullName)\TranslatedText"

    tesseract $ImageFile $OutputFile -c "tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-0123456789 " --psm 7

    return Get-Content "$OutputFile.txt"
}

while($true)
{
    if(PauseBreakDown)
    {
        Write-Verbose 'Got input!'
        
        $File = "$env:LOCALAPPDATA\Temp\Image.png"
        # Gather Screen resolution information
        $Screen = [System.Windows.Forms.SystemInformation]::VirtualScreen

        $MousePos = Get-CursorPos

        $Width = 200
        $Height = 20
        $Left = $MousePos.X + 15
        $Top = $MousePos.Y - 30

        # Create bitmap using the top-left and bottom-right bounds
        $bitmap = New-Object System.Drawing.Bitmap $Width, $Height
        # Create Graphics object
        $graphic = [System.Drawing.Graphics]::FromImage($bitmap)
        # Capture screen
        $graphic.CopyFromScreen($Left, $Top, 0, 0, $bitmap.Size)
        # Save to file
        $bitmap.Save($File)

        Write-Verbose 'Screenshot saved'

        $text = GetImageText $File

        Write-Verbose "Export complete! Export was $text"

        if(-not [string]::IsNullOrEmpty($text))
        {
            Query-TarkovDB($text.subString(0, [System.Math]::Min(15, $text.Length)))

            Write-Verbose 'Query complete!'
        }
    }
}