#Requires -RunAsAdministrator

# Wish I could use [System.Environment]::OSVersion.Version, but there's no documentation on what Windows 11 is vs Windows 10. Major version is the same between the two
$OsName = (Get-ComputerInfo).OSName

# I know this is dirty, but meh. Made it easier in my head.
$IsWin10 = $OSName.Contains("Windows 10")
$IsWin11 = $OSName.Contains("Windows 11")

if(-not ($IsWin10 -or $IsWin11)) # Not Windows 10 or 11.
{
	Write-Error "This script is not supported on this version of Windows."
	return
}

$Personal = $False

# Check if this is for a personal or work computer. Changes what applications are installed.
$confirmation = Read-Host "Is this a personal computer? [y/N]"
if ($confirmation -eq 'y') {
    $Personal = $True
}

# Install WinGet if it's not already installed.
if(-not (Get-Command winget))
{
	Add-AppxPackage https://aka.ms/getwinget
}

# MsStore source is really busted. Remove it.
winget source remove msstore

# Install programs for both Windows 10 and Windows 11.
if($IsWin10 -or $IsWin11)
{
	winget install Microsoft.PowerToys
	if($lastexitcode -eq 0) { Write-Host "Powertoys installed successfully." }
	winget install Microsoft.WindowsTerminal
	if($lastexitcode -eq 0) { Write-Host "Windows Terminal installed successfully." }
	winget install Notepad++.Notepad++ # Maybe install a profile for Notepad++? I have one made already.
	if($lastexitcode -eq 0) { Write-Host "Notepad++ installed successfully." }
	winget install 7zip.7zip
	if($lastexitcode -eq 0) { Write-Host "7Zip installed successfully." }
	winget install ShareX.ShareX
	if($lastexitcode -eq 0) { Write-Host "ShareX installed successfully." }
	winget install voidtools.Everything
	if($lastexitcode -eq 0) { Write-Host "Everything Search installed successfully." }
	winget install Git.Git
	if($lastexitcode -eq 0) { Write-Host "Git installed successfully." }
	winget install IrfanSkiljan.IrfanView
	if($lastexitcode -eq 0) { Write-Host "IrfanView installed successfully." }
	winget install Audacity.Audacity
	if($lastexitcode -eq 0) { Write-Host "Audacity installed successfully." }
	
	if($Personal) # Install programs that aren't fit for work computers.
	{
		winget install Valve.Steam
		if($lastexitcode -eq 0) { Write-Host "Steam installed successfully." }
		winget install Discord.Discord
		if($lastexitcode -eq 0) { Write-Host "Discord installed successfully." }
		winget install Spotify.Spotify
		if($lastexitcode -eq 0) { Write-Host "Spotify installed successfully." }
		winget install Parsec.Parsec
		if($lastexitcode -eq 0) { Write-Host "Parsec installed successfully." }
		winget install ZeroTier.ZeroTierOne
		if($lastexitcode -eq 0) { Write-Host "ZeroTier One installed successfully." }
		winget install Lexikos.AutoHotkey
		if($lastexitcode -eq 0) { Write-Host "AutoHotkey installed successfully." }
	} else
	{
		winget install SonicWALL.GlobalVPN
		if($lastexitcode -eq 0) { Write-Host "SonicWALL Global VPN Client installed successfully." }
	}
}

# Install programs for Windows 10.
if($IsWin10)
{
	winget install Open-Shell.Open-Shell-Menu # Maybe install a profile for OpenShell? I have one made already.
	if($lastexitcode -eq 0) { Write-Host "OpenShell installed successfully." }
} elseif($IsWin11) # Install programs for Windows 11.
{
	winget install StartIsBack.StartAllBack
	if($lastexitcode -eq 0) { Write-Host "StartAllBack installed successfully." }
}

if($?)
{
	Write-Host "Setup completed successfully, enjoy Windows!"
} else
{
	Write-Error "There was an error, please review output and manually install what was missed, or correct errors and rerun script."
}
