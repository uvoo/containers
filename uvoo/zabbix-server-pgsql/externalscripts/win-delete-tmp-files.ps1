# Powershell script to delete temporary windows files to free up disk space

# $objShell = New-Object -ComObject Shell.Application
# $recycle_bin = $objShell.Namespace(0xA)
$evtid=99999
$user_tmp = get-childitem "env:\TEMP" | foreach { $_.Value }
$dirs = @(
    "$user_tmp",
    "$env:SystemDrive\tmp",
    "$env:SystemDrive\Temp"
    "$env:SystemDrive\Windows\Temp",
    "$env:SystemDrive\Windows\Logs\CBS",
    "$env:SystemDrive\swtools",
    "$env:SystemDrive\drivers",
    "$env:SystemDrive\swsetup",
    "$env:SystemDrive\users\administrator\downloads",
    "$env:SystemDrive\Windows\Prefetch",
    "$env:SystemDrive\Windows\SoftwareDistribution\Download"
)


function clear_tmp_dirs() {
    foreach ($dir in $dirs) {
        remove-item $dir\* -recurse -force -verbose -erroraction 'silentlycontinue'
        # Write-EventLog -LogName "Application" -Source "DiskCleanupScript" -EventID $evtid -EntryType Information -Message "DiskCleanup delted the content of $dir" -Category 1 -RawData 10,20
    }
    Clear-RecycleBin -force
}


function main() {
    clear_tmp_dirs
}

main


## NOTES ##
# cleanmgr.exe is deprecated but could be used from admin gui if needed.
# https://en.wikipedia.org/wiki/Disk_Cleanup#:~:text=Microsoft%20announced%20that%20Disk%20Clean,the%20legacy%20Disk%20Cleanup%20provides!
