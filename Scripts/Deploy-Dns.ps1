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

$rgEnvName = 'dns-rg'
Write-Host "Target RG name for base resources is [$rgEnvName] ..."

$OptionalParameters = New-Object -TypeName Hashtable
$OptionalParameters['environment'] = $environment
$OptionalParameters['appCode'] = $appCode
$OptionalParameters['friendlyLocation'] = $friendlyLocation

$templateFile = $PSScriptRoot + '\..\Templates\Base\Template-Dns.json'
$paramFile = $PSScriptRoot + '\..\Templates\Base\Param-Dns.json'

Write-Host "Base template file is [$templateFile]"
Write-Host "Base parameters file is [$paramFile]"

#Deploy Base template
try {
    Write-Host "Deploying base template  $rg RG ..."
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

