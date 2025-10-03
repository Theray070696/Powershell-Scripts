######################################################################################################################
# Uses GPU accelerated HEVC/AV1 compression to reduce file size without visibly effecting quality.
# FFMPEG commands come from EposVox, who wrote a .bat version I based this script on.
# Only works on Nvidia GPUs with a hardware encoder (experimental support for Intel/AMD GPUs WiP).
# Written by RantingRaymond. My other scripts can be found at https://www.github.com/Theray070696/Powershell-Scripts
######################################################################################################################

[CmdletBinding()]
param
(
    [string] $Path,
    [switch] $Recurse,
    [switch] $AutoDelete, # Note, I'd recommand leaving this off and manually checking the files so you're not left with a file that had a broken encode and no original. I haven't had this happen yet, but I'm not responsible for any loss caused by this switch.
    [switch] $AV1,
    [switch] $HEVC,
	[switch] $AMD,
	[switch] $Intel
)

$Version = 1.2.1

function CompleteNotification
{
    [void] [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')

    $objNotifyIcon = New-Object System.Windows.Forms.NotifyIcon

    $objNotifyIcon.Icon = [System.Drawing.SystemIcons]::Information
    $objNotifyIcon.BalloonTipIcon = 'Info' 
    $objNotifyIcon.BalloonTipText = 'Compression Complete'
    $objNotifyIcon.BalloonTipTitle = 'Video Compression Completed'
    $objNotifyIcon.Visible = $True

    $objNotifyIcon.ShowBalloonTip(10000)
}

function Compress-File($File)
{
    if($HEVC)
    {
        if($File.Name.EndsWith('_HEVC.mp4') -or $File.Name.EndsWith('_AV1.mp4'))
        {
            Write-Host $File.Name is already compressed
            return
        }
		
		$Encoder = "hevc_"
		
		if($AMD)
		{
			$Encoder += "amf"
		} elseif($Intel)
		{
			$Encoder += "qsv"
		} else
		{
			$Encoder += "nvenc"
		}
		
		$EncoderLevel = 20
        
		if(-not $AMD)
		{
			if($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent)
			{
				ffmpeg -hwaccel auto -i $File.FullName -map 0:v -map 0:a? -c:v $Encoder -rc constqp -qp $EncoderLevel -b:v 0K -c:a aac -b:a 384k "$($File.Directory)\$($File.BaseName)_QP$($EncoderLevel)_HEVC.mp4"
			} else
			{
				ffmpeg -hwaccel auto -i $File.FullName -map 0:v -map 0:a? -c:v $Encoder -rc constqp -qp $EncoderLevel -b:v 0K -c:a aac -b:a 384k "$($File.Directory)\$($File.BaseName)_QP$($EncoderLevel)_HEVC.mp4" -hide_banner -loglevel error -stats
			}
		} else # FUCK YOU BALTIMORE
		{
			if($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent)
			{
				ffmpeg -hwaccel auto -i $File.FullName -map 0:v -map 0:a? -c:v $Encoder -rc cqp -qp_i $EncoderLevel -qp_p $EncoderLevel -b:v 0K -c:a aac -b:a 384k "$($File.Directory)\$($File.BaseName)_QP$($EncoderLevel)_HEVC.mp4"
			} else
			{
				ffmpeg -hwaccel auto -i $File.FullName -map 0:v -map 0:a? -c:v $Encoder -rc cqp -qp_i $EncoderLevel -qp_p $EncoderLevel -b:v 0K -c:a aac -b:a 384k "$($File.Directory)\$($File.BaseName)_QP$($EncoderLevel)_HEVC.mp4" -hide_banner -loglevel error -stats
			}
		}

        if($AutoDelete -and $LastExitCode -eq 0)
        {
            $NewFile = Get-Item -Path "$($File.Directory)\$($File.BaseName)_QP$($EncoderLevel)_HEVC.mp4"

            if(Test-Path "$($File.Directory)\$($File.BaseName)_QP$($EncoderLevel)_HEVC.mp4")
            {
                if($NewFile.Length -gt $File.Length)
                {
                    Write-Host Original file is smaller
                    $NewFile | Remove-Item
                    Move-Item -Path $File.FullName -Destination "$($File.Directory)\$($File.BaseName)_QP$($EncoderLevel)_HEVC.mp4"
                } elseif($File.Length -gt $NewFile.Length)
                {
                    Write-Host Compressed file is smaller
                    $File | Remove-Item
                }
            }
        }
    } elseif($AV1)
    {
        if($File.Name.EndsWith('_AV1.mp4'))
        {
            Write-Host $File.Name is already compressed
            return
        }
        
        #Write-Host "AV1 Encoding is in very early testing. So early that it's not even implemented. Will update as I get GPUs."
        #return
		
		$Encoder = "av1_"
		
		if($AMD)
		{
			$Encoder += "amf"
		} elseif($Intel)
		{
			$Encoder += "qsv"
		} else
		{
			$Encoder += "nvenc"
		}
		
		$EncoderLevel = 100
        
        if($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent)
        {
            ffmpeg -hwaccel auto -i $File.FullName -map 0:v -map 0:a? -c:v $Encoder -rc constqp -qp $EncoderLevel -b:v 0K -c:a aac -b:a 384k "$($File.Directory)\$($File.BaseName)_QP$($EncoderLevel)_AV1.mp4"
        } else
        {
            ffmpeg -hwaccel auto -i $File.FullName -map 0:v -map 0:a? -c:v $Encoder -rc constqp -qp $EncoderLevel -b:v 0K -c:a aac -b:a 384k "$($File.Directory)\$($File.BaseName)_QP$($EncoderLevel)_AV1.mp4" -hide_banner -loglevel error -stats
        }

        if($AutoDelete -and $LastExitCode -eq 0)
        {
            $NewFile = Get-Item -Path "$($File.Directory)\$($File.BaseName)_QP$($EncoderLevel)_AV1.mp4"

            if(Test-Path "$($File.Directory)\$($File.BaseName)_QP$($EncoderLevel)_AV1.mp4")
            {
                if($NewFile.Length -gt $File.Length)
                {
                    Write-Host Original file is smaller
                    $NewFile | Remove-Item
                    Move-Item -Path $File.FullName -Destination "$($File.Directory)\$($File.BaseName)_QP$($EncoderLevel)_AV1.mp4"
                } elseif($File.Length -gt $NewFile.Length)
                {
                    Write-Host Compressed file is smaller
                    $File | Remove-Item
                }
            }
        }
    }
}

function Compress-Folder([string]$Folder)
{
    $ChildItems = Get-ChildItem -Path $Folder
    
    ForEach($Item in $ChildItems)
    {
        if($Recurse -and $Item -is [System.IO.DirectoryInfo])
        {
            Write-Host Compressing directory $Item.FullName
            Compress-Folder $Item.FullName
        } elseif($Item.Extension -eq '.MP4' -or $Item.Extension -eq '.MKV' -or $Item.Extension -eq '.MOV' -or $Item.Extension -eq '.WMV')
        {
            Write-Host Compressing $Item.Name
            Compress-File $Item
        } elseif($Item.Name.EndsWith('_HEVC.mp4'))
        {
            Write-Host $Item.Name is already compressed
        }
    }
}

if($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne 'Import-Module')
{
    if(-not (Get-Command ffmpeg))
    {
        # FFMPEG not found.
        Write-Error FFMPEG not found, please install it and add it to your PATH.
        return
    }
    
    if([string]::IsNullOrEmpty($Path))
    {
        $Path = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }

    $Target = Get-Item $Path

    if($Target -is [System.IO.DirectoryInfo])
    {
        # This is a directory
        if($Recurse)
        {
            Write-Host Compressing directory $Target.FullName and sub-directories
        } else
        {
            Write-Host Compressing directory $Target.FullName
        }

        Compress-Folder $Target.FullName

        CompleteNotification
    } elseif(($Target.Extension -eq '.MP4' -or $Target.Extension -eq '.MKV' -or $Target.Extension -eq '.MOV' -or $Target.Extension -eq '.WMV') -and -not $Target.Name.EndsWith('_HEVC.mp4'))
    {
        # This is a file
        Write-Host Compressing $Target.Name

        Compress-File $Target

        CompleteNotification
    } elseif($HEVC -and ($Target.Name.EndsWith('_HEVC.mp4') -or $Target.Name.EndsWith('_AV1.mp4')))
    {
        Write-Host $Target.Name is already compressed
    } elseif($AV1 -and $Target.Name.EndsWith('_AV1.mp4'))
    {
        Write-Host $Target.Name is already compressed
    }
}
