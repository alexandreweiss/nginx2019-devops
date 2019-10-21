Param(
    [string] #[Parameter(Mandatory=$true)]
	[ValidateSet('westus2', 'francecentral', IgnoreCase = $false)]
    $location = 'westus2',

    [string] #[Parameter(Mandatory=$true)]
	[ValidateSet('dev', 'prd', IgnoreCase = $false)]
    $environment = 'prd',

    [string] #[Parameter(Mandatory=$true)]
	[ValidateSet('nginx2019', IgnoreCase = $false)]
    $appCode = 'nginx2019',

    [string] #[Parameter(Mandatory=$true)]
	[ValidateSet('wus', 'frc', IgnoreCase = $false)]
    $friendlyLocation = 'wus',

    [string]$PfxFilePath  = "C:\Users\alweiss\OneDrive - Microsoft\Documents\nginxconf2019\alweiss-nginx-client-cert.pfx",

    [string] [Parameter(Mandatory=$true)]
    $PfxCertPassword,

    [string][ValidateSet('nginxClientCert')]
    $CertName = 'nginxClientCert'
    )
    
    Function Upload-Cert {
    Param(
        [string]$VaultName,
        [string]$PfxFilePath,
        [string]$PfxCertPassword,
        [string]$CertName
    )
    
      $_cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 ($PfxFilePath, $PfxCertPassword)
      $_bytes = [system.IO.File]::ReadAllBytes($PfxFilePath)
      $_base64 = [System.Convert]::ToBase64String($_bytes)
    
      $_jsonBlob = @{
         data = $_base64
         dataType = 'pfx'
         password = $PfxCertPassword
      } | ConvertTo-Json
    
      $_contentbytes = [System.Text.Encoding]::UTF8.GetBytes($_jsonBlob)
      $_content = [System.Convert]::ToBase64String($_contentbytes)
    
      $_secretValue = ConvertTo-SecureString -String $_content -AsPlainText -Force
    
      $_secret = Set-AzKeyVaultSecret -VaultName $VaultName -Name $CertName -SecretValue $_secretValue
    
      $_output = @{};
      $_output.CertificateURL = $_secret.Id;
      $_output.CertificateThumbprint = $_cert.Thumbprint;
    
      return $_output
    }
    
$vaultName = $friendlyLocation + '-' + $environment + '-' + $appCode + '-kv'
try {
    Write-Host "Storing secret to keyvault ..."
    $output = Upload-Cert -VaultName $VaultName -PfxFilePath $PfxFilePath -PfxCertPassword $PfxCertPassword -CertName $CertName
}
catch {
    $ErrorMessage = $_.Exception.Message      
    throw "Error while deploying template:`nException: $ErrorMessage"      
}


write-host ($output | Out-String)