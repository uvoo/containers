#!/bin/bash
# For use when public fqdn is disabled
set -eu

sleep_seconds=1
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <Resource Group> <AKS Cluster Name>"
  echo "Example: $0 myaks-rgrp myaks"
  exit
fi
rg=$1
aks_name=$2


update_etc_hosts(){
  rg=$1
  aks_name=$2

  fqdn=$(az aks show --name "$aks_name" --resource-group "$rg" --query 'privateFqdn' -o tsv)
  zone=$(echo "$fqdn" | cut -d'.' -f2-)
  ipaddr=$(az network private-dns record-set a list --resource-group "$rg" --zone "$zone" --query "[0].aRecords[0].ipv4Address" -o tsv)
  echo "ip: $ipaddr fqdn: $fqdn"
  hosts_file="/etc/hosts"
  # grep -q "^${ipaddr}" $hosts_file && (sudo sed "s/^$ipaddr.*/$ipaddr $fqdn/" -i $hosts_file || sudo sed "$ a ${ipaddr} ${fqdn}" -i $hosts_file)
  if grep -q "^${ipaddr}" $hosts_file; then
    echo "Updating existing /etc/hosts record for $ipaddr"
    # sudo sed "s/^$ipaddr.*/$ipaddr $fqdn/" -i $hosts_file
    # echo $( cat /etc/hosts | sed "s/^$ipaddr.*/$ipaddr $fqdn/" ) | sudo tee /etc/hosts
  else
    echo "Adding /etc/hosts record for $ipaddr"
    echo "${ipaddr} ${fqdn}" | sudo tee -a $hosts_file
    # sudo sed "$ a ${ipaddr} ${fqdn}" -i $hosts_file
  fi
}


update_kube_config(){
  az aks get-credentials --resource-group "$rg" --name "$aks_name" --overwrite-existing && \
  kubelogin convert-kubeconfig -l azurecli
  # kubectl config set-context "$aks_name"
}


main(){
  update_etc_hosts "$rg" "$aks_name"
  echo "I: Update kubeconfig in $sleep_seconds seconds."; sleep $sleep_seconds
  update_kube_config "$rg" "$aks_name"
}


main
