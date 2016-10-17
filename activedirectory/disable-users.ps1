###################################################################
#   disable-users.ps1                                             #
#   By Chad Shaw 09/24/15                                         #
#   Checks for user accounts and prompts to disable them          #
#   Usage: .\disable-users.ps1 "John Doe", "Jane Doe"             #
#   Requires: Quest Active Directory Commandlets                  #
###################################################################

PARAM (
        [Parameter(ValueFromPipeline)]
        $FullName
)

$Password = Read-Host -AsSecureString "Enter Your Password" 
$prodcred = New-Object System.Management.Automation.PSCredential ("prod.example.com\username",$Password)
$devcred = New-Object System.Management.Automation.PSCredential ("dev.example.com\username",$Password)
$stagecred = New-Object System.Management.Automation.PSCredential ("stage.example.com\username",$Password)
$outputpath = "C:\Scripts\exports"
$emailbody=New-Object System.Text.StringBuilder

$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
    "Disables User."
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
    "Does NOT Disable User."
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

clear
Foreach ($Name in $FullName) {
    write-host "--------------- Checking accounts for $Name --------------- "
    write-host
    ###################### Prod Account Check ######################
    $prod = Connect-QADService prod.example.com -Credential $prodcred
    $produsers = ($prod | %{Get-QADUser $Name -Connection $_})
    if ($apusers) {
        Foreach ($user in $produsers) {
            $result = $host.ui.PromptForChoice($title, "$user found would you like to disable?", $options, 0) 
            switch ($result) {
                0 {
                    $emailbody=$emailbody.AppendLine($user.ToString() + " disabled")
                    $emailbody=$emailbody.AppendLine("---------------")
                    $groups=($user.MemberOf | Get-QADGroup | select Name)
                    foreach ($group in $groups) {
                        $emailbody=$emailbody.AppendLine(($group.Name).ToString())
                    }
                    $emailbody=$emailbody.AppendLine(" ")
                    write-host "User disabled:" -foregroundcolor yellow
                    ($prod | %{Disable-QADUser $user -Connection $_})
                    write-host "Groups removed:" -foregroundcolor yellow
                    ($prod | %{Remove-QADMemberOf $user -RemoveAll -Connection $_})
                  }
                1 {
                    write-host "Not disabling $user" -foregroundcolor red
                    $emailbody=$emailbody.AppendLine("Not disabling $user")
                  }
            }
            write-host
        }       
    } else {
        write-host "prod.example.com\$Name not found" -foregroundcolor green
        $emailbody=$emailbody.AppendLine("ap\$Name not found")
    }
    $ap = Disconnect-QADService

    ###################### Dev Account Check ######################
    $dev = Connect-QADService dev.example.com -Credential $devcred
    $devusers = ($dev | %{Get-QADUser $Name -Connection $_})
    if ($devusers) {
        Foreach ($user in $devusers) {
            $result = $host.ui.PromptForChoice($title, "$user found would you like to disable?", $options, 0) 
            switch ($result) {
                0 {
                    $emailbody=$emailbody.AppendLine($user.ToString() + " disabled")
                    $emailbody=$emailbody.AppendLine("---------------")
                    $groups=($user.MemberOf | Get-QADGroup | select Name)
                    foreach ($group in $groups) {
                        $emailbody=$emailbody.AppendLine(($group.Name).ToString())
                    }
                    $emailbody=$emailbody.AppendLine(" ")
                    ($dev | %{Disable-QADUser $user -Connection $_})
                    write-host "User disabled" -foregroundcolor yellow
                    ($dev | %{Remove-QADMemberOf $user -RemoveAll -Connection $_})
                    write-host "Groups removed" -foregroundcolor yellow
                  }
                1 {
                    write-host "Not disabling $user" -foregroundcolor red | write-host
                    $emailbody=$emailbody.AppendLine("Not disabling $user")
                  }
            }
            write-host
        }       
    } else {
        write-host "dev.example.com\$Name not found" -foregroundcolor green
        $emailbody=$emailbody.AppendLine("dev\$Name not found")
    }
    $dev = Disconnect-QADService

    ###################### Stage Account Check ######################
    $stage = Connect-QADService stage.example.com -Credential $stagecred
    $stageusers = ($stage | %{Get-QADUser $Name -Connection $_})
    if ($stageusers) {
        Foreach ($user in $stageusers) {
            $result = $host.ui.PromptForChoice($title, "$user found would you like to disable?", $options, 0) 
            switch ($result) {
                0 {
                    $emailbody=$emailbody.AppendLine($user.ToString() + " disabled")
                    $emailbody=$emailbody.AppendLine("---------------")
                    $groups=($user.MemberOf | Get-QADGroup | select Name)
                    foreach ($group in $groups) {
                        $emailbody=$emailbody.AppendLine(($group.Name).ToString())
                    }
                    $emailbody=$emailbody.AppendLine(" ")
                    ($stage | %{Disable-QADUser $user -Connection $_})
                    write-host "User disabled" -foregroundcolor yellow
                    ($stage | %{Remove-QADMemberOf $user -RemoveAll -Connection $_})
                    write-host "Groups removed" -foregroundcolor yellow
                  }
                1 {
                    write-host "Not disabling $user" -foregroundcolor red | write-host
                    $emailbody=$emailbody.AppendLine("Not disabling $user")
                  }
            }
            write-host
        }       
    } else {
        write-host "stage.example.com\$Name not found" -foregroundcolor green
        $emailbody=$emailbody.AppendLine("cimasystems\$Name not found")
    }
    $cima = Disconnect-QADService
    write-host
}

Send-MailMessage -Subject "Disabled Users" -From "user@example.com" -To "DL@example.com" -SmtpServer "smtp.example.com" -body $emailbody
