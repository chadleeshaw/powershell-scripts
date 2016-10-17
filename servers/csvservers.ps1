###################################################################
#   CSVServers.ps1                                                #
#   By Chad Shaw 11/26/14                                         #
#   Gathers MWI info about computer passed from ImportServers.csv #
#   Usage: .\CSVServers.ps1                                       #
###################################################################

$ProdUserName = " " # Prod UserName
$DevUserName = " " # Dev  UserName
$BOUserName = " " # Back Office UserName

$Password = Read-Host -AsSecureString "Enter Your Password" 
$path = "c:\scripts\CSVServers.csv"

# Header for CSV
$csv = "Name,Domain,Manufacturer,Model,Service Tag,BIOS Version,Drac Version,Drac Firmware,Physical Memory,Total Processors,CPU Name,Total Cores,Operating System,Architecture,Network Adapter,IP Address,Subnet,Default Gateway, DNS, Mac Address,TotalDiskSpace`r`n"

write-host
write-host "Gathering Data"

import-csv ImportServers.csv | foreach {
   write-host -NoNewLine "."
   If (Test-Connection -Cn $_.strComputer -count 1 -buffersize 16 -ea 0 -quiet) # test if server name can be resolved and ping
   {
      $DomainPosition = $_.strComputer.IndexOf(".") # Determine Username based on fqdn provided
      $Domain = $_.strComputer.substring($DomainPosition+1)
      Switch ($Domain) {
         "ap.local" { $UserName = $ProdUserName }
         "dev.local" { $UserName = $DevUserName }
         "na.audatex.com" { $UserName = $BOUserName }
      }
      
      $cred = New-Object System.Management.Automation.PSCredential ($UserName,$Password)
      
      if (Get-WmiObject -cn $_.strComputer -ea 'silentlycontinue' -Credential $cred -class Win32_ComputerSystem | Select Name) #Test if server responds to MWI calls
      {
         $cred = New-Object System.Management.Automation.PSCredential ($UserName,$Password)
         $Compute = get-wmiobject -Class Win32_ComputerSystem -credential $cred -ComputerName $_.strComputer | select @{name="PhysicalMemory";Expression={"{0:N2}" -f($_.TotalPhysicalMemory/1gb).tostring("N0")}},NumberOfProcessors,Name,Domain,Manufacturer,Model
         $Proc = Get-WMIObject -Class Win32_Processor -credential $cred -ComputerName $_.strComputer | select Name, NumberOfCores | select -First 1
         $Bios = Get-WMIObject -Class Win32_Bios -credential $cred -ComputerName $_.strComputer | select SerialNumber, SMBIOSBIOSVersion
         If (Get-WMIObject -List -Namespace 'root\cimv2\dell' -ea 0) {
            $Drac = Get-WMIObject -Class Dell_Firmware -NameSpace root\cimv2\dell -credential $cred -ComputerName $_.strComputer | select Name, Version | Select -First 1
         } 
         $OS = Get-WMIObject -Class Win32_OperatingSystem -credential $cred -ComputerName $_.strComputer
         $Network = Get-WmiObject Win32_NetworkAdapterConfiguration -credential $cred -ComputerName $_.strComputer -filter "IPEnabled ='true'" | Select -First 1
         $Disks = Get-WmiObject Win32_LogicalDisk -credential $cred -ComputerName $_.strComputer | where {$_.Description -eq "Local Fixed Disk"}
         
         foreach ($Disk in $Disks) {
            $LocalDisk += $Disk.Size
         }
                 
         $LocalDisk = ($LocalDisk/1gb)
         $compute.Manufacturer = $compute.Manufacturer -replace "," -replace "  "
   
         $csv += $Compute.Name + "," +
            $Compute.Domain + "," +
            $Compute.Manufacturer + "," + 
            $Compute.Model + "," + 
            $Bios.SerialNumber + "," + 
            $Bios.SMBIOSBIOSVersion + "," + 
            $Drac.Name + "," +
            $Drac.Version + "," +
            $Compute.PhysicalMemory+ "," + 
            $Compute.NumberOfProcessors + "," + 
            $Proc.Name + "," + 
            $Proc.NumberOfCores + "," + 
            $OS.Caption + "," + 
            $OS.OSArchitecture + "," + 
            $Network.Description + "," + 
            $Network.IPAddress + "," + 
            $Network.IPSubnet + "," + 
            $Network.DefaultIPGateway + "," + 
            $Network.DNSServerSearchOrder + "," + 
            $Network.MacAddress + "," +
            ("{0:F2}" -f $LocalDisk)
            $csv += "`r`n"
      } else {
          $csv += $_.strComputer + "," + "Non Microsoft Device,`r`n"
      }
    } else {
        $csv += $_.strComputer + "," + "Server Could Not be contacted,`r`n"
    }
}

$fso = new-object -comobject scripting.filesystemobject
$file = $fso.CreateTextFile($path,$true)
$file.write($csv)
$file.close()
write-host
