Param(
   [string] [Parameter(Mandatory=$false)] $VmName,
   [switch] [Parameter(Mandatory=$false)] $GetCred,
   [switch] [Parameter(Mandatory=$false)] $GetVmDisk,
   [switch] [Parameter(Mandatory=$false)] $GetVmInfo,
   [switch] [Parameter(Mandatory=$false)] $InvokeCmdAllVms,
   [switch] [Parameter(Mandatory=$false)] $SetVmDisk
)
if ($GetCred){
  $Cred = Get-Credential
}
$minDiskSize = 80  # In GBs
$ErrorActionPreference = 'Stop'
$hardDisk1Name = "Hard disk 1"

$vCenters = @("wjv-vmc01.example.com", "txv-vmc01.example.com")
Connect-VIServer -Server $vCenters


function getGuestOs($vmGuest){
  if ( $vmGuest -Like "*Windows*" ) {
    # Write-Host "vm: $vm os: $vmGuest is Windows"
    return "Windows"
  } elseif ( $vmGuest -Like "*Linux*" ) {
    # Write-Host "vm: $vm os: $vmGuest is Linux"
    return "Linux"
  } else {
    # Write-Host "$vm is Undetected/Unsupported.\n"
    return "Undetected"
  }
}


function guestIsWindows($vmGuest){
  if ( $vmGuest -Like "*Windows*" ) {
    Write-Output "$vmGuest is Windows"
    return $true
  } else {
    return $false
  }
}


function guestIsLinux($vmGuest){
  Write-Output $vmGuest
  if ( $vmGuest -Like "*Linux*" ) {
    return $true
  } else {
    return $false
  }
}


function resizeDiskToMaxSize ($name){
  Invoke-Command -ComputerName $name -ScriptBlock { Update-Disk -Number 0; Resize-Partition -DriveLetter C -Size $(Get-PartitionSupportedSize -DriveLetter C).SizeMax} -cred $cred
}


function Invoke-Command-On-All-VMs($cmd) {
  # $vmlist = Get-Cluster $vCluster | Get-VM
  $vmlist = Get-VM
  # | Select @{N="IP Address";E={@($_.guest.IPAddress[0])}}

  foreach ($vm in $vmlist) {
    # $vm = Get-VM $vm | Select-Object -Property *
    $vmGuest = $vm.Guest
    $vmPowerState = $vm.PowerState
    Write-Host "$vm $vmGuest $vmPowerState"
    $os = getGuestOs($vmGuest)
    if ($os -eq "Windows"){
      Write-Output "OS is Windows."
      try {
        $r = Invoke-VMScript -vm $vm -ScriptText $cmd -ScriptType Powershell -GuestCredential $Cred
        Write-Output $r
      } catch { $e = $_.Exception.Message; Write-Output $e }
    } elseif ($os -eq "Linux"){
      Write-Output "OS is Linux."
      try {
        $r = Invoke-VMScript -vm $vm -ScriptText $cmd -ScriptType Bash -GuestCredential $Cred
        Write-Output $r
      } catch { $e = $_.Exception.Message; Write-Output $e }
    } else {
      Write-Output "W: OS is unsupported."
    }
    Start-Sleep 5
  }
}


function Get-vmInfo ($vmName) {
  $vm = Get-VM -Name $vmName | Select-Object -Property *
  Write-Output $vm
  $vmDisk = Get-VM $vmName | Get-Harddisk | Select-Object -Property *
  Write-Output $vmDisk
}


function Get-vmDisk ($vmName, $hardDiskName) {
  $vm = Get-VM -Name $vmName | Select-Object -Property *
  # $vmDisk = Get-HardDisk -VM $vm
  $vmDisk = Get-VM $vmName | Get-Harddisk -Name $hardDiskName | Select-Object -Property *
  if ( $vmDisk.CapacityGB -lt $minDiskSize ) {
    Write-Output "W: $vmName current size $($vmDisk.CapacityGB) GB is < than min $minDiskSize GB"
    if (guestIsWindows($vm.Guest)){
      Write-Output "OS is Windows."
    }
  } else {
    Write-Output "I: $vmName current size $($vmDisk.CapacityGB) GB is > than min $minDiskSize GB"
  }
}


function SetIncreaseVmDiskToMinSize($vmName, $hardDiskName){
  $vmDisk = Get-VM -Name $vmName | Get-Harddisk -Name $hardDiskName | Select-Object -Property *
  Write-Output $vmDisk.CapacityGB
  if ( $vmDisk.CapacityGB -lt $minDiskSize ) {
    Write-Output "W: $vmName current size $($vmDisk.CapacityGB) GB is < than min $minDiskSize GB"
    Get-HardDisk -VM $vm -Name $hardDiskName | Set-HardDisk -CapacityGB $minDiskSize
    if (guestIsWindows($vm.Guest)){
      Write-Output "Expand $vmName drive C to max partition size."
      $script0 = "Update-Disk -Number 0; Resize-Partition -DriveLetter C -Size $(Get-PartitionSupportedSize -DriveLetter C).SizeMax"
      Invoke-VMScript $script0 -vm $vmName -GuestCredential $Cred
    }
  } else {
    Write-Output "I: $vmName current size $($vmDisk.CapacityGB) GB is > than min $minDiskSize GB"
  }
}


function main(){
  if ($GetVmDisk) {
    Get-VmDisk $vmName $hardDisk1Name
  }
  if ($GetVmInfo) {
    Get-VmInfo $vmName
  }
  if ($SetVmDisk) {
    SetIncreaseVmDiskToMinSize $vmName $hardDisk1Name
  }
  if ($InvokeCmdAllVms) {
    Invoke-Command-On-All-VMs "hostname" 
    # Invoke-Command-On-All-VMs("pwd; ls")
  }
}


main


# NOTES ===============================================

# Register-DNSClient
