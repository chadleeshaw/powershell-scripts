###################################################################
#   find-vm.ps1                                                   #
#   By Chad Shaw 10/10/16                                         #
#   Find Hyper-V VM(s)                                            #
#   Usage: .\find-vm.ps1 servername                               #
#   Version: 1.0                                                  #
###################################################################

# vm_names parameter
Param (
    [parameter(
        Mandatory=$true,
        HelpMessage='Specify VM name(s) IE server1,server2')]
        [array]$vm_names
)

# init variables (Place hyper-v servers in same OU)
$DC1_OU = [ADSI]"LDAP://OU=Computers,DC=dc1,DC=com"
$DC2_OU = [ADSI]"LDAP://OU=Computers,DC=dc2,DC=com"
$datacenters = @()
$hvhosts = @()
$count = 1
$found = 0

# Generate unique list of data centers
foreach ($vm_name in $vm_names) {
    $datacenters += $vm_name.Substring(0, ($vm_name.IndexOf("-") ))
}
$datacenters = $datacenters.ToLower() | Get-Unique


# Generate Hyper-V hosts array's
If ($datacenters -contains "dc1") {
    foreach ($child in $DC1_OU.PSBase.Children){
        if ($child.ObjectCategory -like '*computer*'){
            $hvhosts += $child.Name.Value
        }
    }
}
If ($datacenters -contains "dc2") {
    foreach ($child in $DC2_OU.PSBase.Children){
        if ($child.ObjectCategory -like '*computer*'){
            $hvhosts += $child.Name.Value
        }
    }
}
$hvhosts = $hvhosts | Get-Unique | Sort-Object

# Search for VM's
$total = $hvhosts.count

Write-Progress -Id 1 -Activity "Searching Hyper-V Hosts..." -Status "Starting search" -PercentComplete 0

foreach ($hvhost in $hvhosts) {
    if ($found -ne $vm_names.Count) {
        $vms = Get-VM -ComputerName $hvhost -ErrorAction SilentlyContinue
        Write-Progress -Id 1 -Activity "Searching Hyper-V Hosts..." -Status $hvhost -PercentComplete (($count / $total)  * 100)
        if ($vms) {
            foreach ($vm in $vms) {
                foreach ($vm_name in $vm_names) {
                    if ($vm.Name -like $vm_name) {
                        write-host "$vm_name is on $hvhost" -ForegroundColor Green
                        $found++
                    }
                }
            }
        } else {
            write-host "[Error] - Can't search $hvhost" -ForegroundColor Red
        }
        $count++
    } else {
        break
    }
}
Write-Progress -Id 1 -Activity "Searching Hyper-V Hosts..." -Status "Search Complete" -PercentComplete 100
Start-Sleep 1
Write-Progress -Id 1 -Activity "Searching Hyper-V Hosts..." -Status "Search Complete" -Completed
