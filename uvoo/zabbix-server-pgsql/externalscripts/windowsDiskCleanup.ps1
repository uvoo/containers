# Powershell script to delete temporary windows files to free up disk space

$name = "windowsDiskCleanup"
$version = "0.2.22"

# $objShell = New-Object -ComObject Shell.Application
# $recycle_bin = $objShell.Namespace(0xA)

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
    "$env:SystemDrive\users\*\downloads",
    "$env:SystemDrive\Windows\Prefetch"
)

#HELPER FUNCTIONS
#folder size in MB
function foldersize($dir) {
    $folderSizeinbyte = (Get-ChildItem $folder -Recurse | Measure-Object -property length -sum)
    $folderSizeinMB=($folderSizeinbyte.sum / 1048576)
    return $folderSizeinMB
}

## LOG EVENT CODES ##
# 1 = Error - Failure in execution of the windowsDiskCleanup Culling Action (small piece)
# 0 = Informational - Successful execution of the windowsDiskCleanup Culling Action (small piece)
# 2 = Informational - Successful completion of ALL defined culling actions wihtin windowsDiskCleanup Script
# 3 = Critical - Failure to complete ALL defined culling actions wihtin windowsDiskCleanup Script
# 4 = Warning - Culling Path is invalid / Does not exist

#CULLING FUNCTIONS

function clear_windowsupdate_cache() {
    # Windows update service locks this directory so we need to stop the service
    # and clean the directory.  When that is complete, we restart the service and
    # the directory is recreated automatcially.
    Stop-Service -Name wuauserv -PassThru
    #Remove-Item -Recurse is not as reliable as it should be so we are using Get-ChildItem
    Get-ChildItem "$env:SystemDrive\Windows\SoftwareDistribution" -Include * -Recurse | Remove-Item -Recurse
    Start-Service -Name wuauserv -PassThru
}

function clear_tmp_dirs() {
    foreach ($dir in $dirs) {
        # Efficiency is to create a loop to andle the paths and functions for the system actions
        # We will add some error catching for the paths passwed to the cleanup functions
        # Since we are logging to the windows event channel we have the ability to craft our own error messages in each level of the process
        try{Test-Path($dir)}
        catch{
            #Exit with Warning, EventID 4, culling path invalid
            Write-EventLog -LogName "Application" -Source "windowsDiskCleanup" -EventID 4 -EntryType Warning -Message "Warning: Invalid path passed to culling function. path=\"$dir\"" -Category 1 -RawData 10,20
        }
        finally {
            $d = Test-Path($dir)
        }
        if($d) {
            try{
                #If path is valid cull content
                [double]$ca = foldersize($dir)
                Remove-Item -Recurse  "$dir\*" -Force -ErrorAction SilentlyContinue #-Verbose
                [double]$cb = foldersize($dir)
                $total=$ca-$cb
                [Math]::Round($total / 1MB)
            }
            catch{
                #Exit with Error, EventID 1, failed culling action
                Write-EventLog -LogName "Application" -Source "windowsDiskCleanup" -EventID 1 -EntryType Error -Message "Error: Failed to cull the content of '$dir'" -Category 1 -RawData 10,20
            }
            finally{
                #Exit with Informational, EventID 0, sucessfull culling action
                Write-EventLog -LogName "Application" -Source "windowsDiskCleanup" -EventID 0 -EntryType Information -Message "Success: Culled ($total) of content from '$dir'" -Category 1 -RawData 10,20
                $ca=0
                $cb=0
                $total=0
            }
        }
    }
}

#clear recycleBin
function emptyBin() {
    try{(Clear-RecycleBin -force)}
    catch{
        #Exit with Warning, EventID 1, failed to empty recycle bin
        Write-EventLog -LogName "Application" -Source "windowsDiskCleanup" -EventID 1 -EntryType Warning -Message "Warning: Failed to empty the recycle bin." -Category 1 -RawData 10,20
    }
    #Exit with Informational, EventID 0, sucessfull culling action
    Write-EventLog -LogName "Application" -Source "windowsDiskCleanup" -EventID 0 -EntryType Information -Message "Success: Emptied the recycle bin." -Category 1 -RawData 10,20
}

#flush DNS cache
function clearDNSCache() {
    try{(Clear-DnsClientCache)}
    catch{
        #Exit with Warning, EventID 1, failed to empty recycle bin
        Write-EventLog -LogName "Application" -Source "windowsDiskCleanup" -EventID 1 -EntryType Warning -Message "Warning: Failed to clear the DNS-client cache." -Category 1 -RawData 10,20
    }
    #Exit with Informational, EventID 0, sucessfull culling action
    Write-EventLog -LogName "Application" -Source "windowsDiskCleanup" -EventID 0 -EntryType Information -Message "Success: Cleared the DNS-Client cache." -Category 1 -RawData 10,20
}


function flushBranchCache() {
    try{(netsh branchcache flush)}
    catch{
        #Exit with Warning, EventID 1, failed to flush the branchcache
        Write-EventLog -LogName "Application" -Source "windowsDiskCleanup" -EventID 1 -EntryType Warning -Message "Warning: Netsh failed to flush the branchcache." -Category 1 -RawData 10,20
    }
    #Exit with Informational, EventID 0, sucessfull culling action
    Write-EventLog -LogName "Application" -Source "windowsDiskCleanup" -EventID 0 -EntryType Information -Message "Success: Netsh flushed the branchcache." -Category 1 -RawData 10,20
}

#create logsource if needed
function logSource(){
    $s = [System.Diagnostics.EventLog]::SourceExists("windowsDiskCleanup");

    if($s -eq $false){
        try{
            New-EventLog -LogName Application -Source windowsDiskCleanup
            }
        catch{
           #Exit with Error
           exit(2)
        }
        finally{
          #Log Source Creation Succedded
          #Exit with Informational, EventID 0
          Write-EventLog -LogName "Application" -Source "windowsDiskCleanup" -EventID 0 -EntryType Information -Message "Success: Created the windowsDiskCleanup source." -Category 1 -RawData 10,20
        }
    }
}

function driveSpaceFree(){
$disk = Get-PSDrive C | Select-Object Used,Free
return $disk.Free
}

function main() {
    #Add Log Source If Needed
    logSource

    #get total size before culling actions
    [double]$a = driveSpaceFree

    #Culling Actions
    clear_tmp_dirs
    emptyBin
    clearDNSCache
    flushBranchCache
    clear_windowsupdate_cache


    #get drive size after culling actions
    [double]$b = driveSpaceFree

    #calculate total recalimed space
    $totalFree = $a-$b
    [Math]::Round($totalFree / 1MB)

    Write-Output "windowsDiskCleanup reclaimed ($totalFree MB) total."
    Write-EventLog -LogName "Application" -Source "windowsDiskCleanup" -EventID 0 -EntryType Information -Message "Success: windowsDiskCleanup reclaimed ($totalFree MB) total." -Category 1 -RawData 10,20

    #reset
    $a = 0
    $b = 0
    $totalFree = 0
}

main

## NOTES ##
# cleanmgr.exe is deprecated but could be used from admin gui if needed.
# https://en.wikipedia.org/wiki/Disk_Cleanup#:~:text=Microsoft%20announced%20that%20Disk%20Clean,the%20legacy%20Disk%20Cleanup%20provides!clear
