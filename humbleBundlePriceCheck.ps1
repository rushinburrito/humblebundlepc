# Get Script Current Location
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition

# Definitions
$pricelog = $scriptpath+'\humblebundleprice.txt'
$bundlenamefile = $scriptPath+'\humblebundlename.txt'
$price_array=@{}
$userAgent = [Microsoft.PowerShell.Commands.PSUserAgent]::InternetExplorer

#Read the current log of bundle prices and write a new line if the price has changed
function Update-Price ([string]$price) {
    if ($previousprice.Count -eq 1) {
        Write-Host 'First price in new file is' $price
        Get-Date -Format G | Out-File -Append $pricelog
        $price | Out-File -Append $pricelog
    }
    elseif ($price -gt 0 -and $previousprice[$previousprice.Count-1] -ne $price) {
        Write-Host $price '!=' $previousprice[$previousprice.Count-1] ' so file updated'
        Get-Date -Format G | Out-File -Append $pricelog
        $price | Out-File -Append $pricelog
    }
    elseif (!($price) -or ($price -eq 0)) {
        Write-Host 'price not defined'
    }
    else {
        Write-Host $price '==' $previousprice[$previousprice.Count-1] 'so file not updated'
    }
    
}

# Create a template pricelog file if no such file exists
if (!(Test-Path $pricelog)) {
    "99.99" | Out-File $pricelog
    Write-Host $pricelog 'created'
}
$previousprice = Get-Content $pricelog
$price_array = $previousprice | Select-String '\d+\.\d+' | Sort-Object

$bundle_uri = 'http://www.humblebundle.com/'

# Main function

# If bundle name file does not exist (i.e. it's been deleted because there's a new bundle), 
# get the name of the bundle from the Humble Bundle Homepage and store it in the bundle name file

if (!(Test-Path $bundlenamefile)) {
    $page = (Invoke-WebRequest -UseBasicParsing -Uri $bundle_uri -UserAgent $userAgent).Content
    # The bundle name is in the HTMl source as "bundlename_bundle", so we grab the first instance of that in the code
    $bundlename = ($page | Select-String -Pattern '\w+_bundle').Matches[0].Value
    $bundlename | Out-File $bundlenamefile
    Write-Host $bundlenamefile 'created with name ' $bundlename
}

# Read name of bundle from bundle name file and make request to PubNub (who provides Humble Bundle's purchase statistics
# to determine the current average price of the bundle. This request returns a JSON object and is much faster than
# loading the full page and parsing it for the current average price

# Values in the pubnub_url have been determined by loading the Humble Bundle site and watching network traffic in
# developer tools in Chrome on the humble bundle site. It regularly makes calls to pubnub once the page has loaded.
# The hardcoded values below were determined by comparing requests of different bundles and determining a URL pattern
$bundlename = Get-Content $bundlenamefile
$pubnub_url = 'https://ps.pubnub.com/subscribe/6b5eeae3-796b-11df-8b2d-ef048cc31d2e/humble' + $bundlename + '/0/15086161607336235'
$pubnub_response = (Invoke-WebRequest -UseBasicParsing -Uri $pubnub_url -UserAgent $userAgent).Content
$pubnub_json = $pubnub_response.ToString() | ConvertFrom-Json
$average_raw = ($pubnub_json[0].stats.rawtotal/$pubnub_json[0].stats.numberofcontributions.total)
$averageprice = [math]::round($average_raw,2)

# Launch browser if historically lowest price. Default browser is used.
if ($averageprice -lt $price_array[0].ToString()) {
    Invoke-Expression "cmd /C start $bundle_uri"
}
Write-Host $pricelog 'Lowest price is' $price_array[0] 'and current price is' $averageprice
Update-Price($averageprice)