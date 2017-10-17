#Get Script Current Location
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition

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

$filename = $scriptpath+'\humblebundleregular.txt'
if (!(Test-Path $filename)) {
    "99.99" | Out-File $filename
    Write-Host $filename 'created'
}
$prev_price = Get-Content $filename
$price_array = $prev_price | Select-String '\d+\.\d+' | Sort-Object

$bundle_uri = 'http://www.humblebundle.com/'

# Main function

$page = Read-HtmlPage($bundle_uri)
$price = $page.getElementsByTagName('h2') | where 'classname' -like '*dd-header-headline*' | select -ExpandProperty innertext
$price | % { if ($_ -match '\d+\.\d+') { $averageprice = $Matches[0] } }

# Launch browser if historically lowest price. Default browser is used.
if ($averageprice -and $averageprice -lt $price_array[0]) {
    Invoke-Expression "cmd /C start $bundle_uri"
}
Write-Host $filename 'Lowest price is' $price_array[0] 'and current price is ' $averageprice
Update-Price($averageprice)