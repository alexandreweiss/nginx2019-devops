param(
    # $services = @('azure-maps-nginx2019','google-maps-nginx2019'),
    # $urlSuffixes = @('/search/poi/json?api-version=1&query=photographer&lat=50.5240219&lon=1.5820351&radius=100','/maps/api/streetview?size=1024x768&location=50.5240219%2C1.5820351&heading=240.00&pitch=-2&fov=40'),
    $serviceUrls = @(
        @('azureMaps','azure-maps-nginx2019','/search/poi/json?api-version=1&query=photographer&lat=50.5240219&lon=1.5820351&radius=100'),
        @('googleMaps','google-maps-nginx2019','/maps/api/streetview?size=1024x768&location=50.5240219%2C1.5820351&heading=240.00&pitch=-2&fov=40')
    ),
    [string]
    [ValidateSet('myapigw.site')]
    $externalDomain = 'myapigw.site',

    [string] #[Parameter(Mandatory=$true)]
    [ValidateSet('westus2', 'francecentral', IgnoreCase = $false)]
    $location = 'westus2',

    [string] #[Parameter(Mandatory=$true)]
    [ValidateSet('dev', 'prd', IgnoreCase = $false)]
    $environment = 'dev',

    [string] #[Parameter(Mandatory=$true)]
    [ValidateSet('wus', 'frc', IgnoreCase = $false)]
    $friendlyLocation = 'wus'
)

function TestMyUrl {
    param(
        [string]$urlToTest
    )

    $myTestResult = Invoke-WebRequest "$urlToTest" -ErrorAction SilentlyContinue

    if ($myTestResult) {
        return $myTestResult.StatusCode
    }
    else {
        return 500
    }

}

#Preload load featureFlags settings
$featureFlagsFile = 'ff-' + $friendlyLocation + '-' + $environment + '.json'
$featureFlags = Get-Content $($PSScriptRoot + "\..\Nginx\" + $featureFlagsFile) | ConvertFrom-Json

ForEach ($serviceUrl in $serviceUrls) {
    if ($featureFlags.featureFlags.$($serviceUrl[0])){
        Write-Host "Feature $($serviceUrl[0]) is enabled, testing ..."
        $urlToTest = 'http://' + $serviceUrl[1] + '.' + $friendlyLocation + '.' + $environment + '.' + $externalDomain + $serviceUrl[2]
        $resultCode = TestMyUrl -urlToTest $urlToTest
        
        if ($resultCode -ne '200') {
            Write-Host -ForegroundColor Red "Test failed for [$urlToTest]. Response code is [$resultCode] ..."

        }
        else {
            Write-Host -ForegroundColor Green "Release went fine for [$urlToTest], code is [$resultCode]"
        }
    }
    else
    {
        Write-Host "Feature $($serviceUrl[0]) is not enabled, bypassing ..."
    }
}

