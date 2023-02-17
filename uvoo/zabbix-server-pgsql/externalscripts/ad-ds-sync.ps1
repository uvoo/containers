# Powershel source script:
# https://github.com/chrisdee/Scripts/blob/master/PowerShell/Working/AD/GetADReplicationStatusReportHTML.ps1
$array = @()
$myForest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
$dclist = $myforest.Sites | % { $_.Servers } 

foreach ($dcname in $dclist) {
    $source_dc_fqdn = ($dcname.Name).tolower()
    $ad_partition_list = repadmin /showrepl $source_dc_fqdn | select-string "dc="
    foreach ($ad_partition in $ad_partition_list) {        
        $result = repadmin /showrepl $source_dc_fqdn $ad_partition
        $result = $result | Where-Object { ([string]::IsNullOrEmpty(($result[$_]))) }
        $index_array_dst = 0..($result.Count - 1) | Where-Object { $result[$_] -like "*via RPC" }
        foreach ($index in $index_array_dst) {
            $dst_dc = ($result[$index]).trim()
            $next_index = [array]::IndexOf($index_array_dst, $index) + 1           
            $msg = ""
            if ($index -lt $index_array_dst[-1]) {
                $last_index = $index_array_dst[$next_index]
            }
            else {
                $last_index = $result.Count
            }
 
            for ($i = $index + 1; $i -lt $last_index; $i++) {
                if (($msg -eq "") -and ($result[$i])) {
                    $msg += ($result[$i]).trim()
                }
                else {
                    $msg += " / " + ($result[$i]).trim()
                }
            }
            $Properties = @{source_dc = $source_dc_fqdn; NC = $ad_partition; destination_dc = $dst_dc; repl_status = $msg }
            $Newobject = New-Object PSObject -Property $Properties
            $array += $newobject
        }
    }
}
 
$status_repl_ko = "Active Directory Replication Problem : "
$status_repl_ok = "Active Directory Replication OK. "

$message = "" 
if ($array | Where-Object { $_.repl_status -notlike "*successful*" }) {
    $message += $status_repl_ko
    $message += $array | Where-Object { $_.repl_status -notlike "*successful*" } | Select-Object source_dc, nc, destination_dc, repl_status | ConvertTo-Json       
}
else {
    $message += $status_repl_ok    
    $message += " No problem detected."
}
 
Write-Host $message