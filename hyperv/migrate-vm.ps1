###################################################################
#   vm-migrate.ps1                                                #
#   By Chad Shaw 10/03/16                                         #
#   Hyper-V Live Migration Utility                                #
#   Usage: .\vm-migrate.ps1 or .\vm-migrate -details $true        #
#   Version: 1.0                                                  #
###################################################################
 
#region variables
 
Param (
    [parameter(
        Mandatory=$false,
        HelpMessage='Detailed Host Data')]      
        [bool]$details = $false
)
 
$DC1_Hosts = (' ')
$DC2_Hosts = (' ')
$DC3_Hosts = (' ')
 
$hvhosts_obj = @()
$count = 0
$global:confirm = $false
 
#endregion
 
#region functions
 
Function sPrint {
 
    param( [byte]$Type=1,[string]$Message )
 
    $Time = Get-Date -Format "HH:mm:ss"
 
    if ($Type -eq 1) { Write-Host "[INFO]    - $Time - $Message" -ForegroundColor Green }
    elseif ($Type -eq 2) { Write-Host "[WARNING] - $Time - $Message" -ForegroundColor Yellow }
    elseif ($Type -eq 0) { Write-Host "[ERROR] - $Time - $Message" -ForegroundColor Red }
}
 
Workflow Invoke-ParallelLiveMigrate {
 Param (
    [parameter(Mandatory=$true)][psobject[]] $VMList
    )
 
    ForEach -Parallel ($VM in $VMList) {
        Move-VM -ComputerName $VM.SourceHost -Name $VM.VM -DestinationHost $VM.DestHost -DestinationStoragePath $VM.DestPath
    }
}
 
#endregion
 
#region select datacenter
 
$datacenter = ('DC1','DC2','DC3') | Out-GridView -Title "Pick the Datacenter" -OutputMode Single
 
if ($datacenter -eq "DC1") {
    sPrint -Type 1 "Datacenter is set to: $datacenter"
    $HVHosts = $DC1_Hosts
} ElseIF ($datacenter -eq "DC2"
    sPrint -Type 1 "Datacenter is set to: $datacenter"
    $HVHosts = $DC2_Hosts
} ElseIF ($datacenter -eq "DC3") {
    sPrint -Type 1 "Datacenter is set to: $datacenter"
    $HVHosts = $DC3_Hosts
} Else {
    sPrint -Type 0 "Error selecting Datacenter"
    break
 }
 
#endregion
 
#region generate Hypver-V host data
 
sPrint -Type 1 -Message "Gathering Hyper-V host data"
 
if ($details) {
 
    ForEach ($HVHost in $HVHosts ) {
        $mem = (get-wmiobject -ComputerName $HVHost -ErrorAction SilentlyContinue -Class win32_operatingSystem FreephysicalMemory).FreePhysicalMemory/1mb
        if ($mem) {
            $mem = "{0:N0}" -f $mem
            $disk = Get-WmiObject Win32_LogicalDisk -ComputerName $HVHost -Filter "DeviceID='C:'" | Select-Object Size,FreeSpace
            $disk = ($disk.FreeSpace/1gb)
            $disk = "{0:N0}" -f $disk
            $cpu = Get-Counter -ComputerName $HVHost -ErrorAction SilentlyContinue -Counter "Hyper-V Hypervisor Logical Processor(_Total)\% Total Run Time" -MaxSamples 2 -SampleInterval 1 | ForEach-Object { $_.CounterSamples } | Measure-Object -Property CookedValue -Average
            $cpu = "{0:N0}" -f $cpu.Average
            if ($cpu -eq $null) {
                sPrint -Message "Get-Counter Could Not Connect to: $HVHost" -Type 0
            }
 
            $obj = new-object psobject
            $obj | add-member –membertype NoteProperty –name "HVHost" –value $HVHost
            $obj | add-member –membertype NoteProperty –name "CPUPercent" –value $cpu
            $obj | add-member –membertype NoteProperty –name "FreeMemoryGB" –value $mem
            $obj | add-member –membertype NoteProperty –name "FreeDiskGB" –value $disk
            $hvhosts_obj += $obj
        } else {
            sPrint -Type 0 -Message "WMI Could Not Connect to: $HVHost"
        }
        $count++
        Write-Progress -Activity "Gathering Hypver-V Host data" -status "Host $count of $($HVHosts.Count)" -percentComplete (($count / $HVHosts.Count)  * 100)
    }
    Write-Progress -Activity "Gathering Hypver-V Host data" -Status "Ready" -Completed
} else {
    ForEach ($HVHost in $HVHosts) {
        $wmi_check = Get-WmiObject Win32_OperatingSystem -ComputerName $HVHost -ErrorAction SilentlyContinue
        if ($wmi_check) {
            $obj = new-object psobject
            $obj | add-member –membertype NoteProperty –name "HVHost" –value $HVHost
            $hvhosts_obj += $obj
        }else {
            sPrint -Type 0 -Message "WMI Could Not Connect to: $HVHost"
        }
        $count++
        Write-Progress -Activity "Gathering Hypver-V Host data" -status "Host $count of $($HVHosts.Count)" -percentComplete (($count / $HVHosts.Count)  * 100)
    }
    Write-Progress -Activity "Gathering Hypver-V Host data" -Status "Ready" -Completed
}
 
#endregion
 
#region get source Hyper-V host
 
$source_host = $hvhosts_obj | Out-GridView -Title "Select Hyper-V Host to Migrate From" -OutputMode Single
$source_host = $source_host.HVHost
if ($source_host -eq $null) {
    sPrint -Type 0 -Message "Source host not selected"
    break
} else {
    sPrint -Type 1 -Message "Source host set to: $source_host"
}
$source_model = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $source_host | select Model
 
#endregion
 
#region get VM(s) to migrate
 
sPrint -Type 1 -Message "Gathering VM data"
$vm_selection = Get-VM -ComputerName $source_host | Out-GridView -Title "Select the VM's to Migrate" -OutputMode Multiple
$vm_selection = $vm_selection.Name
if ($vm_selection -eq $null) {
    sPrint -Type 0 -Message "VM's not selected"
    break
} else {
    sPrint -Type 1 -Message "The following VM's have been selected: $vm_selection"
}
 
 
#endregion
 
#region get destination Hyper-V host
 
$dest_host = $hvhosts_obj | Out-GridView -Title "Select Hyper-V Host to Migrate To" -OutputMode Single
$dest_host = $dest_host.HVHost
 
if ($dest_host -eq $null) {
    sPrint -Type 0 -Message "Destination host not selected"
    break
} else {
    if ($dest_host -eq $source_host) {
        sPrint -Type 2 -Message "Source and Destination host cannot be the same"
        break
    }
    $dest_model = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $dest_host | select Model
    if (($source_model -like '*620*') -and ($dest_model -like '*630*')) {
        sPrint -Type 0 -Message "You can't migrate from an old server to a new one"
        break
    }
    sPrint -Type 1 -Message "Destination host set to: $source_host"
}
 
#endregion
 
#region confirm selections
 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
 
$objForm = New-Object System.Windows.Forms.Form
$objForm.Text = "Confirm Live Migration"
$objForm.Size = New-Object System.Drawing.Size(500,300)
$objForm.StartPosition = "CenterScreen"
 
$objForm.KeyPreview = $True
$objForm.Add_KeyDown({if ($_.KeyCode -eq "Enter")
    {$x=$objTextBox.Text;$objForm.Close()}})
$objForm.Add_KeyDown({if ($_.KeyCode -eq "Escape")
    {$objForm.Close()}})
 
$OKButton = New-Object System.Windows.Forms.Button
$OKButton.Location = New-Object System.Drawing.Size(75,220)
$OKButton.Size = New-Object System.Drawing.Size(75,23)
$OKButton.Text = "OK"
$OKButton.Add_Click({$global:confirm = $true;$objForm.Close()})
$objForm.Controls.Add($OKButton)
 
$CancelButton = New-Object System.Windows.Forms.Button
$CancelButton.Location = New-Object System.Drawing.Size(160,220)
$CancelButton.Size = New-Object System.Drawing.Size(75,23)
$CancelButton.Text = "Cancel"
$CancelButton.Add_Click({$objForm.Close()})
$objForm.Controls.Add($CancelButton)
 
$objLabel = New-Object System.Windows.Forms.Label
$objLabel.Location = New-Object System.Drawing.Size(10,20)
$objLabel.Size = New-Object System.Drawing.Size(475,275)
$objLabel.Text = "Hit OK to confirm or Cancel to stop migration
 
Migrate from    : $source_host
 
Migrate to       : $dest_host
 
Migrate VM's  : $vm_selection"
$objForm.Controls.Add($objLabel)
 
$objForm.Topmost = $True
 
$objForm.Add_Shown({$objForm.Activate()})
[void] $objForm.ShowDialog()
 
#endregion
 
#region directory prep and live migration
 
if ($global:confirm) {
 
    #prepare destination folder(s)
 
    $C_Path = "\\$dest_host\c$\Virtual Machines"
    $Cluster_Path = "\\$dest_host\c$\ClusterStorage"
    $D_Path = "\\$dest_host\d$"
    $E_Path = "\\$dest_host\e$"
 
    sPrint -Type 1 -Message "Checking folder placement"
 
    foreach ($vm in $vm_selection) {
         
        $cluster_disk = $false
        $vhds = Get-VM -ComputerName $source_host -Name $vm | Get-VMHardDiskDrive | select Path
        foreach ($vhd in $vhds) {
            If ($vhd.Path -like "*ClusterStorage*") { $cluster_disk = $true }
        }
 
        If (($cluster_disk) -and (Test-Path $Cluster_Path\$vm)) {
            sPrint -Type 1 -Message "Folder exists at $Cluster_Path\$vm"
            $dest_path = "$Cluster_Path\$vm"
        } ElseIf (Test-Path $C_Path\$vm) {
            sPrint -Type 1 -Message "Folder exists at $C_Path\$vm"
            $dest_path = "$C_Path\$vm"
        } ElseIf (Test-Path $D_Path\$vm) {
            sPrint -Type 1 -Message "Folder exists at $D_Path\$vm"
            $dest_path = "$D_Path\$vm"
        } ElseIf (Test-Path $E_Path\$vm) {
            sPrint -Type 1 -Message "Folder exists at $E_Path\$vm"
            $dest_path = "$E_Path\$vm"
        } Else {
            If ($cluster_disk) {
                sPrint -Type 1 -Message "Created folder $Cluster_Path\$vm"
                New-Item -Path "$Cluster_Path\$vm" -type directory -Force | out-null
                $dest_path = "$Cluster_Path\$vm"
            } ElseIf (Test-Path $C_Path) {
                sPrint -Type 1 -Message "Created folder $C_Path\$vm"
                New-Item -Path "$C_Path\$vm" -type directory -Force | out-null
                $dest_path = "$C_Path\$vm"
            } ElseIf (Test-Path $D_Path) {
                sPrint -Type 1 -Message "Created folder $D_Path\$vm"
                New-Item -Path "$D_Path\$vm" -type directory -Force | out-null
                $dest_path = "$D_Path\$vm"
            } ElseIf (Test-Path $E_Path) {
                sPrint -Type 1 -Message "Created folder $E_Path\$vm"
                New-Item -Path "$E_Path\$vm" -type directory -Force | out-null
                $dest_path = "$E_Path\$vm"
            } Else {
                sPrint -Type 0 -Message "Destination folder for $vm could not be created"
                break
            }
        }
 
        $vm_list = new-object psobject
        $vm_list | add-member –membertype NoteProperty –name "VM" –value $vm
        $vm_list | add-member –membertype NoteProperty –name "SourceHost" –value $source_host
        $vm_list | add-member –membertype NoteProperty –name "DestHost" –value $dest_Host
        $vm_list | add-member –membertype NoteProperty –name "DestPath" –value $dest_path
 
        ### Turn off Time Sync ###
        Disable-VMIntegrationService -name "Time Synchronization" -ComputerName $source_host -VMName $vm
        sPrint -Type 1 -Message "Turned off Time Synchronization for $vm"
 
        ### Move VM(s) ###
        try {
            Invoke-ParallelLiveMigrate -VMList $vm_list -AsJob -JobName $vm -Verbose 4>&1 | out-null
        } catch {
            sPrint -Type 0 -Message "Migration failed to start"
        }
    }
} else {
    sPrint -Type 0 -Message "Migration was canceled"
    break
}
sPrint -Type 1 -Message "Starting Live Migration(s)"
#endregion
 
#region Job check
 
$jobs = Get-Job
 
Foreach ($job in $jobs) {
    Write-Progress -Id $job.Id -Activity "Live Migration Job" -Status "Starting Live Migration" -PercentComplete 0
}
 
Do {
    ForEach ($job in $jobs) {
        if ($job.State -eq "Running") {
            try {
                $progress = (Get-Job $job.Id -ErrorAction SilentlyContinue).ChildJobs[0].Progress.PercentComplete[-1]
                $name = ($job.Name).ToString()
                Write-Progress -Id $job.Id -Activity "Live Migration Job" -Status "$name : $progress%" -PercentComplete $progress
                Start-Sleep -Seconds 1
            } catch {
                Start-Sleep -Seconds 1
            }
        }
    }
  
} Until (($jobs | Where State -eq "Running").Count -eq 0)
 
If ($job.State -eq "Completed") {
    foreach ($job in $jobs) {
        $name = $job.Name
        Write-Progress -Id $job.Id -Activity "Live Migration Job" -Status "Execution Done" -PercentComplete 100
        Write-Progress -Id $job.Id -Activity "Live Migration Job" -Status "Execution Done" -Completed
        try {
            Receive-Job -Job $job -Keep -OutVariable job_output -ErrorVariable job_error | Out-Null
            if ($job_error -like '*failed*' -or $job_error -like '*error*') {
                sPrint -Type 2 -Message "Migration of $name failed"
                write-host
            } else {
                sPrint -Type 1 -Message "Migration of $name succeeded"
                write-host
            }
        } catch {
            sPrint -Type 0 -Message "Couldn't get $name output"
        }
    }
    sPrint -Type 1 -Message "Live Migrations Complete" 
}
 
$jobs | Remove-Job -Force
 
#endregion
