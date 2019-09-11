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

$rgEnvName = $friendlyLocation + '-' + $environment + '-' + $appCode
$baseRgEnvName = $rgEnvName + '-base'
Write-Host "Base RG name is [$rgEnvName] ..."

$rgList = @($rgEnvName,$baseRgEnvName,'dns-rg')

#Create all resource groups
foreach ($rg in $rgList) {
    try {
        Write-Host "Creating $rg RG ..."
        New-AzResourceGroup -Name $rg -Location $location -Force
        Write-Host "RG $rg created ..."
    }
    catch [System.Exception] {
        $ErrorMessage = $_.Exception.Message      
        throw "Error while creating RG:`nException: $ErrorMessage"      
    }
}
