if ( (get-service | Where-Object {$_.Name -match 'sumo-collector'}).Status -eq "Stopped"){
  $o=$(start-service sumo-collector)
  write-host "output: $o"
}
