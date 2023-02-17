#!/bin/sh
# https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=apt
# sudo is not used on install because of strange issues with packer.
set -e
curl -sL https://aka.ms/InstallAzureCLIDeb | bash
