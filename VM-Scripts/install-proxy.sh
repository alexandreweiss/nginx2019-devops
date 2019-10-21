#!/bin/bash

#All parameters are sent, space seperated when executing the shell.
#Every parameter comes from the CommandToExecute ARM Template variable
updateOs=${1}
epelVersion=${2}
ansibleVersion=${3}
nginxSetMiscVersion=${4}
nginxNdkVersion=${5}
nginxNjsVersion=${6}
nginxVersion={$7}
nginxCertificateThumbprint=${8}
env=${9}
ggStreetViewApiKey=${10}
workspaceId=${11}
workspaceKey=${12}
googleStreetViewEndpoint=${13}
azureMapsEndpoint=${14}
azureMapsApiKey=${15}
friendlyLocation=${16}
azureMapsRateLimitEndpoint=${17}
azureMapsRateLimitValue=${18}
aclStorageAccountName=${19}

# Install updates if required
if [ "$updateOs" == "yes" ]
then
    echo "Updating OS without WALinuxAgent and kernel ..."
    yum --exclude=WALinuxAgent\* --exclude=kernel\* update -y
fi

#Install EPEL
wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
sudo yum -y install epel-release-latest-7.noarch.rpm

# Install ansible
yum -y install "$ansibleVersion" 

# Configure core with ansible
ansible-playbook $PWD/ans-main.yml -c local -i $PWD/ans-inventory.yml --extra-vars \
"updateOs=$updateOs \
epelVersion=$epelVersion \
ansibleVersion=$ansibleVersion \
nginxVersion=$nginxVersion \
nginxSetMiscVersion=$nginxSetMiscVersion \
nginxNdkVersion=$nginxNdkVersion \
nginxNjsVersion=$nginxNjsVersion \
nginxVersion=$nginxVersion \
nginxCertificateThumbprint=$nginxCertificateThumbprint \
env=$env \
ggStreetViewApiKey=$ggStreetViewApiKey \
workspaceId=$workspaceId \
workspaceKey=$workspaceKey \
googleStreetViewEndpoint=$googleStreetViewEndpoint \
azureMapsEndpoint=$azureMapsEndpoint \
azureMapsApiKey=$azureMapsApiKey \
friendlyLocation=$friendlyLocation \
azureMapsRateLimitEndpoint=$azureMapsRateLimitEndpoint \
azureMapsRateLimitValue=$azureMapsRateLimitValue \
aclStorageAccountName=$aclStorageAccountName"