#Get Script Current Location
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition

#Check bundle type. Must specify "weekly" or "regular" when calling the script
$bundleType = $args[0]
if ($bundleType -ne "weekly" -and $bundleType -ne "regular") {
    break
    }

#Random script delay of 0-60 seconds
$delay_seconds = get-random -Minimum 0 -Maximum 30
Start-Sleep $delay_seconds

$price_array=@{}
function Read-HtmlPage {
    param ([Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)][String] $Uri)

    # Invoke-WebRequest and Invoke-RestMethod can't work properly with UTF-8 Response so we need to do things this way.
    [Net.HttpWebRequest]$WebRequest = [Net.WebRequest]::Create($Uri)
    $WebRequest.ContentType = "text/json"
    $WebRequest.Method = "GET"
        
    [Net.HttpWebResponse]$WebResponse = $WebRequest.GetResponse()
    $Reader = New-Object IO.StreamReader($WebResponse.GetResponseStream())
    $Response = $Reader.ReadToEnd()
    $Reader.Close()

    # Create the document class
    [mshtml.HTMLDocumentClass] $Doc = New-Object -com "HTMLFILE"
    $Doc.IHTMLDocument2_write($Response)
    
    # Returns a HTMLDocumentClass instance just like Invoke-WebRequest ParsedHtml
    $Doc
}

#Read the current log of bundle prices and write a new line if the price has changed
function Update-Price ([string]$price) {
    if ($price -and $prev_price[$prev_price.Length-1] -ne $price) {
        Write-Host $price '!=' $prev_price[$prev_price.Length-1] ' so file updated'
        Get-Date -Format G | Out-File -Append $filename
        $price | Out-File -Append $filename
    }
    elseif (!($price)) {
        Write-Host 'price not defined'
    }
    else {
        Write-Host $price '==' $prev_price[$prev_price.Length-1] 'so file not updated'
    }
    
}

$filename = $scriptpath+'\humblebundle'+$bundleType+'.txt'
if (!(Test-Path $filename)) {
    "1/1/2000`r`nPay more than the average of `$99.99" | Out-File $filename
    Write-Host $filename 'created'
}
$prev_price = Get-Content $filename
$price_array = $prev_price | Select-String "Pay"
$price_array = $price_array | Sort-Object

if ($bundleType -eq "weekly") {
    $bundle_uri = 'http://www.humblebundle.com/weekly'
}
else {
    $bundle_uri = 'http://www.humblebundle.com/'
}


$page = Read-HtmlPage($bundle_uri)
$price = $page.getElementsByTagName('div') | where 'classname' -like '*price bta ' | select -ExpandProperty innertext

# Launch browser if historically lowest price. Default browser is used.
if ($price -and $price -lt $price_array[0]) {
    Invoke-Expression "cmd /C start $bundle_uri"
}

Update-Price($price)