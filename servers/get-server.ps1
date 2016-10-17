###################################################################
#   Get-Server.ps1                                                #
#   By Chad Shaw 12/17/14                                         #
#   Gathers MWI info about computer passed from CLI               #
#   Usage: .\Get-Server.ps1 computername                          #
###################################################################

param([string]$strComputer)

$cred = Get-Credential

$colItems = get-wmiobject -Class Win32_ComputerSystem -credential $cred -cn $strComputer | select @{name="PhysicalMemory";Expression={"{0:N2}" -f($_.TotalPhysicalMemory/1gb).tostring("N0")}},NumberOfProcessors,Name,Domain,Manufacturer,Model
foreach ($objItem in $colItems) {
      write-host
      write-host "Host Info               "
      write-host "---------               "
      write-host "Name                  : " $objItem.Name
      write-host "Domain                : " $objItem.Domain
      write-host "Manufacturer          : " $objItem.Manufacturer
      write-host "Model                 : " $objItem.Model
      write-host "Physical Memory       : " $objItem.PhysicalMemory"GB"
      write-host "Total Processors      : " $objItem.NumberOfProcessors
}

$colItems = Get-WMIObject -Class Win32_Processor -credential $cred -ComputerName $strComputer | select Name, NumberOfCores | Select -First 1
foreach ($objItem in $colItems) {
      write-host "CPU                   : " $objItem.Name
      write-host "Total Cores           : " $objItem.NumberOfCores
}

$colItems = Get-WMIObject -Class Win32_Bios -credential $cred -ComputerName $strComputer
foreach ($objItem in $colItems) {
      write-host "Service Tag           : " $objItem.SerialNumber
      write-host "BIOS Version          : " $objItem.SMBIOSBIOSVersion
}

If (Get-WMIObject -List -Namespace 'root\cimv2\dell' -ea 0) {  # If Dell Namespace is installed get Drac information
    $colItems = Get-WMIObject -Class Dell_Firmware -NameSpace root\cimv2\dell -credential $cred -ComputerName $strComputer | select Name, Version | Select -First 1
    foreach ($objItem in $colItems) {
      write-host "Drac Version          : " $objItem.Name
      write-host "Drac Firmware         : " $objItem.Version
    }
} Else {
    write-host "Drac Version          :  Dell Namespace not detected"
    write-host "Drac Firmware         :  Dell Namespace not detected"
}

$colItems = Get-WMIObject -Class Win32_OperatingSystem -credential $cred -ComputerName $strComputer
foreach ($objItem in $colItems) {
      write-host "Operating System      : " $objItem.Caption
      write-host "Architecture          : " $objItem.OSArchitecture
      write-host
}

$colItems = Get-WmiObject Win32_LogicalDisk -credential $cred -computer $strComputer | select @{name="GBFreeSpace";Expression={"{0:N2}" -f($_.FreeSpace/1gb).tostring("N0")}},@{name="GBTotalSpace";Expression={"{0:N2}" -f($_.Size/1gb).tostring("N0")}},DeviceID,Description,ProviderName,VolumeName
      write-host
      write-host "Hard Disk Info            "
      write-host "------------              "
foreach ($objItem in $colItems) {
      write-host "Drive Letter          : " $objItem.DeviceID
      write-host "Description           : " $objItem.Description
      write-host "Mapped Drive          : " $objItem.ProviderName
      write-host "Total Space           : " $objItem.GBTotalSpace"GB"
      write-host "Free Space            : " $objItem.GBFreeSpace"GB"
      write-host
}

$colItems = Get-WmiObject Win32_NetworkAdapterConfiguration -credential $cred -computer $strComputer -filter "IPEnabled ='true'"
      write-host
      write-host "Network Info            "
      write-host "------------            "
foreach ($objItem in $colItems) {
      write-host "Network Adapter       : " $objItem.Description
      write-host "IP Address            : " $objItem.IPAddress
      write-host "Subnet Mask           : " $objItem.IPSubnet
      write-host "Gateway               : " $objItem.DefaultIPGateway
      write-host "DNS                   : " $objItem.DNSServerSearchOrder
      write-host "MAC                   : " $objItem.MacAddress
      write-host
}
