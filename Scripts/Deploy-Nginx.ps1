param(
    [string] #[Parameter(Mandatory=$true)]
	[ValidateSet('westus2', 'francecentral', IgnoreCase = $false)]
    $location = 'westus2',

    [string] #[Parameter(Mandatory=$true)]
	[ValidateSet('dev', 'prd', IgnoreCase = $false)]
    $environment = 'dev',

    [string] #[Parameter(Mandatory=$true)]
	[ValidateSet('nginx2019', IgnoreCase = $false)]
    $appCode = 'nginx2019',

    [string] #[Parameter(Mandatory=$true)]
	[ValidateSet('wus', 'frc', IgnoreCase = $false)]
    $friendlyLocation = 'wus'
)

#Setup vars
#We always need to upload artifacts because of Custom Script Extension
$uploadArtifacts = $true
$ArtifactStagingDirectory = $PSScriptRoot + '\..'

# Write-Host "Base RG name is [$rgcoreName] ..."
$rgEnvName = $friendlyLocation + '-' + $environment + '-' + $appCode
$baseRgEnvName = $friendlyLocation + '-' + $environment + '-' + $appCode + '-base'
Write-Host "Target RG name for nginx resources is [$rgEnvName] ..."

#Artifacts storage account
$StorageAccountName = $friendlyLocation + $environment + $appCode + "sacfg"
$StorageContainerName = $rgEnvName.ToLowerInvariant() + '-stageartifacts'
$artifactsZipFileName = 'nginx-artifacts.zip'

#Certificat retrieval from Keyvault
$keyVaultName = $friendlyLocation + '-' + $environment + '-' + $appCode + '-kv'
$sourceVaultValue = $(Get-AzKeyVault -VaultName $keyVaultName -ResourceGroupName $baseRgEnvName).ResourceId
$nginxCert = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name 'nginxClientCert'
$_contentbytes = [system.Convert]::FromBase64String($nginxCert.SecretValueText)
$_jsonBlob = [System.Text.Encoding]::UTF8.GetString($_contentbytes)
$hash = ConvertFrom-Json $_jsonBlob
$_bytes = [system.Convert]::FromBase64String($hash.data)
$flag = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable
$collection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
$collection.Import($_bytes, $hash.password, $flag)
$nginxClientCertThumbprint = $($collection[$collection.Count-1].Thumbprint).ToUpper()
$nginxClientCertUrl = $nginxCert.Id
##End of certificate retrieval

#Retreive Google StreetView API key
$ggStreetViewApiKey = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name 'ggStreetViewApiKey'
$ggStreetViewApiKeyValue = $ggStreetViewApiKey.SecretValue
##End of Google StreetView API key retrieval

#Retreive Azure Maps API key
$azureMapsApiKey = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name 'azureMapsApiKey'
$azureMapsApiKeyValue = $azureMapsApiKey.SecretValue
##End of Retreive Azure Maps API key retrieval

#Retreive the Log Analytics workspace ID and key
[securestring]$workspaceKey
Write-Host "Grabing Log Analytics Workspace ID and Key ..."
$workspaceName = $friendlyLocation + '-' + $environment + '-oms'
$workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $baseRgEnvName -Name $workspaceName
$workspaceId = $workspace.CustomerId
$workspaceKey = ConvertTo-SecureString -String $($(Get-AzOperationalInsightsWorkspaceSharedKey -ResourceGroupName $baseRgEnvName -Name $workspaceName).PrimarySharedKey) -AsPlainText -Force

$OptionalParameters = New-Object -TypeName Hashtable
$OptionalParameters['workspaceId'] = $workspaceId
$OptionalParameters['workspaceKey'] = $workspaceKey
$OptionalParameters['environment'] = $environment
$OptionalParameters['appCode'] = $appCode
$OptionalParameters['friendlyLocation'] = $friendlyLocation
$OptionalParameters['nginxClientCertThumbprint'] = $nginxClientCertThumbprint
$OptionalParameters['nginxClientCertUrl'] = $nginxClientCertUrl
$OptionalParameters['sourceVaultValue'] = $sourceVaultValue
$OptionalParameters['ggStreetViewApiKey'] = $ggStreetViewApiKeyValue
$OptionalParameters['azureMapsApiKey'] = $azureMapsApiKeyValue



#Template and parameter file section
$templateFile = $PSScriptRoot + '\..\Templates\Main\Template-Nginx.json'
$paramFile = $PSScriptRoot + '\..\Templates\Main\Param-Nginx.json'

Write-Host "Base template file is [$templateFile]"
Write-Host "Base parameters file is [$paramFile]"

#Upload artifacts to the deployment storage account
if ($UploadArtifacts) {
    # Convert relative paths to absolute paths if needed
    $ArtifactStagingDirectory = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $ArtifactStagingDirectory))

    Set-Variable ArtifactsLocationName '_artifactsLocation' -Option ReadOnly -Force
    Set-Variable ArtifactsLocationSasTokenName '_artifactsLocationSasToken' -Option ReadOnly -Force
    Set-Variable StorageContainerVarName 'storageContainerName' -Option ReadOnly -Force

    $OptionalParameters.Add($ArtifactsLocationName, $null)
    $OptionalParameters.Add($ArtifactsLocationSasTokenName, $null)
    $OptionalParameters.Add('storageAccountName', $StorageAccountName)

    # Parse the parameter file and update the values of artifacts location and artifacts location SAS token if they are present
    $JsonContent = Get-Content $paramFile -Raw | ConvertFrom-Json
    $JsonParameters = $JsonContent | Get-Member -Type NoteProperty | Where-Object {$_.Name -eq "parameters"}

    if ($JsonParameters -eq $null) {
        $JsonParameters = $JsonContent
    }
    else {
        $JsonParameters = $JsonContent.parameters
    }

    $JsonParameters | Get-Member -Type NoteProperty | ForEach-Object {
        $ParameterValue = $JsonParameters | Select-Object -ExpandProperty $_.Name

        if ($_.Name -eq $ArtifactsLocationName -or $_.Name -eq $ArtifactsLocationSasTokenName) {
            $OptionalParameters[$_.Name] = $ParameterValue.value
        }
    }

    # Create a storage account name if none was provided
    if($storageAccountName -eq "") {
        $subscriptionId = ((Get-AzContext).Subscription.SubscriptionId).Replace('-', '').substring(0, 19)
        $storageAccountName = "stage$subscriptionId"
    }

    $StorageAccount = (Get-AzStorageAccount | Where-Object{$_.storageAccountName -eq $storageAccountName})

    # Create the storage account if it doesn't already exist
    if($StorageAccount -eq $null){
        $StorageResourceGroupName = $rgEnvName
        New-AzResourceGroup -Location "$location" -Name $StorageResourceGroupName -Force
        $StorageAccount = New-AzStorageAccount -storageAccountName $StorageAccountName -Type 'Standard_LRS' -ResourceGroupName $StorageResourceGroupName -Location "$location"
    }

    $StorageAccountContext = (Get-AzStorageAccount | Where-Object{$_.StorageAccountName -eq $StorageAccountName}).Context

    # Generate the value for artifacts location if it is not provided in the parameter file
    $ArtifactsLocation = $OptionalParameters[$ArtifactsLocationName]
    if ($ArtifactsLocation -eq $null) {
        $ArtifactsLocation = $StorageAccountContext.BlobEndPoint + $StorageContainerName
        $OptionalParameters[$ArtifactsLocationName] = $ArtifactsLocation
    }

    # Copy files from the local storage staging location to the storage account container
    New-AzStorageContainer -Name $StorageContainerName -Context $StorageAccountContext -Permission Off -ErrorAction SilentlyContinue *>&1

    Write-Host "Compressing artifacts file into $ArtifactStagingDirectory\..\$artifactsZipFileName ..."
	Compress-Archive -Path "$ArtifactStagingDirectory\*" -DestinationPath "$ArtifactStagingDirectory\..\$artifactsZipFileName" -Verbose -Force -ErrorAction Stop
	Write-Host "Archive created ... Uploading $artifactsZipFileName ..."
	Set-AzStorageBlobContent -File "$ArtifactStagingDirectory\..\$artifactsZipFileName" -Blob $artifactsZipFileName -Container $StorageContainerName -Context $StorageAccountContext -Force -ErrorAction Stop
    Write-Host "File $artifactsZipFileName uploaded ..."

	$ArtifactFilePaths = Get-ChildItem $ArtifactStagingDirectory -Recurse -File -Filter "ans-*" | ForEach-Object -Process {$_.FullName}
    foreach ($SourcePath in $ArtifactFilePaths) {
        $BlobName = $SourcePath.Substring($ArtifactStagingDirectory.length + 1)
        Set-AzStorageBlobContent -File $SourcePath -Blob $BlobName -Container $StorageContainerName -Context $StorageAccountContext -Force -ErrorAction Stop
    }
	$ArtifactFilePaths = Get-ChildItem $ArtifactStagingDirectory -Recurse -File -Filter "install-proxy*" | ForEach-Object -Process {$_.FullName}
    foreach ($SourcePath in $ArtifactFilePaths) {
        $BlobName = $SourcePath.Substring($ArtifactStagingDirectory.length + 1)
        Set-AzStorageBlobContent -File $SourcePath -Blob $BlobName -Container $StorageContainerName -Context $StorageAccountContext -Force -ErrorAction Stop
    }

    # Generate the value for artifacts location SAS token if it is not provided in the parameter file
    $ArtifactsLocationSasToken = $OptionalParameters[$ArtifactsLocationSasTokenName]
    if ($ArtifactsLocationSasToken -eq $null) {
        # Create a SAS token for the storage container - this gives temporary read-only access to the container
        $ArtifactsLocationSasToken = New-AzStorageContainerSASToken -Container $StorageContainerName -Context $StorageAccountContext -Permission r -ExpiryTime (Get-Date).AddYears(100)
        $ArtifactsLocationSasToken = ConvertTo-SecureString $ArtifactsLocationSasToken -AsPlainText -Force
        $OptionalParameters[$ArtifactsLocationSasTokenName] = $ArtifactsLocationSasToken
    }
}

#Deploy Base template
try {
    Write-Host "Deploying Nginx template to [$rg]s RG ..."
    New-AzResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
        -TemplateFile $templateFile `
        -TemplateParameterFile $paramFile `
        -ResourceGroupName $rgEnvName `
        @OptionalParameters `
        -Verbose
}
catch {
    $ErrorMessage = $_.Exception.Message      
    throw "Error while deploying template:`nException: $ErrorMessage"      
}

