using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$APIName = $TriggerMetadata.FunctionName
Log-Request -user $request.headers.'x-ms-client-principal' -API $APINAME -message 'Accessed this API' -Sev 'Debug'

# List of supported resolvers
$ValidResolvers = @(
    'Google'
    'Cloudflare'
)

# Write to the Azure Functions log stream.
Write-Host 'PowerShell HTTP trigger function processed a request.'
$user = $request.headers.'x-ms-client-principal'

$StatusCode = [HttpStatusCode]::OK
try {
    if (Test-Path 'DnsConfig.json') {
        $Config = Get-Content -Path 'DnsConfig.json' | ConvertFrom-Json
    }
    else {
        $Config = [PSCustomObject]@{
            Resolver = ''
        }
    }
    $updated = $false
    # Interact with query parameters or the body of the request.
    if ($Request.Query.SetConfig) {
        if ($Request.Query.Resolver) {
            $Resolver = $Request.Query.Resolver
            if ($ValidResolvers -contains $Resolver) {
                $Config.Resolver = $Resolver
                $updated = $true
            }
            else {
                Log-Request -API $APINAME -tenant 'Global' -user $request.headers.'x-ms-client-principal' -message "Invalid DNS Resolver - $Resolver" -Sev 'Error' 
                $body = [pscustomobject]@{'Results' = "Error: DNS resolver $Resolver is invalid." }
                $StatusCode = [HttpStatusCode]::BadRequest
            }
        }
        if ($updated) {
            $Config | ConvertTo-Json | Set-Content 'DnsConfig.json'
            Log-Request -API $APINAME -tenant 'Global' -user $request.headers.'x-ms-client-principal' -message 'DNS configuration updated' -Sev 'Info' 
            $body = [pscustomobject]@{'Results' = 'Success: DNS configuration updated.' }
        }
    }
}
catch {
    Log-Request -API $APINAME -tenant $($name) -user $request.headers.'x-ms-client-principal' -message "Exclusion API failed. $($_.Exception.Message)" -Sev 'Error'
    $body = [pscustomobject]@{'Results' = "Failed. $($_.Exception.Message)" }
    $StatusCode = [HttpStatusCode]::BadRequest
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = $body
    })
