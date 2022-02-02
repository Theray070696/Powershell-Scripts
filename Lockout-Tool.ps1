#########################################################################################################################
# A tool that will show all users that are currently locked out on your domain controllers.
# Written by Theray070696. My other scripts can be found at https://www.github.com/Theray070696/Powershell-Scripts
#########################################################################################################################

# Add all your domain controllers here. Comma separated list. If empty, it will grab the domain controller your machine is currently connected to.
$DomainControllers = @("")

#Updates the dropdown with the list of currently locked users.
function UpdateLockedUsers($Dropdown)
{
    $LastCount = $Dropdown.Items.Count
    
    $Dropdown.Items.Clear()
    
    $LockedUsers = New-Object System.Collections.Generic.List[string]
    
    if($DomainControllers.Length -eq 1 -and $DomainControllers[0] -eq "")
    {
        $Users = Search-ADAccount -LockedOut

        ForEach($User in $Users)
        {
            if($User.LockedOut)
            {
                $LockedUsers.Add($User.SamAccountName)
            }
        }
    } else
    {
        $DomainControllers | %{
            $Users = Search-ADAccount -Server $_ -LockedOut

            ForEach($User in $Users)
            {
                if($User.LockedOut)
                {
                    $LockedUsers.Add($User.SamAccountName)
                }
            }
        }
    }
    
    if($LockedUsers.Count -gt 0)
    {
        $UniqueLockedUsers = $LockedUsers | Get-Unique
        $Dropdown.Items.AddRange($UniqueLockedUsers)
        
        if($Dropdown.Items.Count -gt $LastCount)
        {
            $voice.speak("Someone is locked out")
        }
    }

    $LockedUserCountLabel.Text = "Number of Locked Users: " + ($Dropdown.Items.Count)
}

function Lockout-Tool()
{
    $voice = New-Object -ComObject Sapi.spvoice
    $voice.rate = 0

    Add-Type -Assembly System.Windows.Forms

    $main_form = New-Object System.Windows.Forms.Form

    $main_form.Text = "Lockout Tool"
    $main_form.Width = 10
    $main_form.Height = 40
    $main_form.AutoSize = $true

    $Label = New-Object System.Windows.Forms.Label
    $Label.Text = "Locked Users"
    $Label.Location = New-Object System.Drawing.Point(0, 8)
    $Label.AutoSize = $true
    $main_form.Controls.Add($Label)

    $LockedUserCountLabel = New-Object System.Windows.Forms.Label
    $LockedUserCountLabel.Text = "Number of Locked Users: 0"
    $LockedUserCountLabel.Location = New-Object System.Drawing.Point(0, 28)
    $LockedUserCountLabel.AutoSize = $true
    $main_form.Controls.Add($LockedUserCountLabel)

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 30000

    $User_Dropdown = New-Object System.Windows.Forms.ComboBox
    $User_Dropdown.Width = 150
    $User_Dropdown.Location = New-Object System.Drawing.Point(75, 5)
    $main_form.Controls.Add($User_Dropdown)

    $Unlock_Button = New-Object System.Windows.Forms.Button
    $Unlock_Button.Location = New-Object System.Drawing.Size(250, 5)
    $Unlock_Button.Size = New-Object System.Drawing.Size(120, 23)
    $Unlock_Button.Text = "Unlock User"
    $main_form.Controls.Add($Unlock_Button)

    $Unlock_Button.Add_Click(
    {
        if($User_Dropdown.SelectedItem)
        {
            if($DomainControllers.Length -eq 1 -and $DomainControllers[0] -eq "")
            {
                Unlock-ADAccount -Identity $User_Dropdown.SelectedItem
            } else
            {
                $DomainControllers | %{
                    Unlock-ADAccount -Server $_ -Identity $User_Dropdown.SelectedItem
                }
            }
            
            UpdateLockedUsers $User_Dropdown
            $User_Dropdown.Text = ""
        }
    })

    $timer.Add_Tick({UpdateLockedUsers $User_Dropdown})
    $timer.Start()
    $main_form.ShowDialog()
}

if($MyInvocation.InvocationName -ne "." -and $MyInvocation.InvocationName -ne "Import-Module")
{
    Lockout-Tool
}
