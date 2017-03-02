function Get-AppleDeviceInformation
{
    [cmdletbinding()]
    param(
          [Parameter(Mandatory=$true)]
          [System.Management.Automation.PSCredential] $Credential,
          [switch] $WaitForLocationFix = $true)


    $clientBuildNumber = '17AProject83'
    $clientMasteringNumber = '17A77'
    $clientId = '90E1837A-5A86-4FAB-B141-5841BEEEB06E'
    $LoginDataFetchUri = "https://setup.icloud.com/setup/ws/1/login?clientBuildNumber=$clientBuildNumber&clientId=$clientId"

    $PayloadHash = @{
        'apple_id' = $Credential.UserName
        'extended_login' = $false
        'password' = $Credential.GetNetworkCredential().Password
    }

    $PayloadJsonObj = $PayloadHash | ConvertTo-Json -Compress

    $Header = @{
                'Origin' = 'https://www.icloud.com'
                'Referer' = 'https://www.icloud.com/'
               }

    try {
        $LoginData = Invoke-RestMethod -Uri $LoginDataFetchUri -Body $PayloadJsonObj -Headers $Header -Method Post -SessionVariable iCloudSession -UserAgent ([Microsoft.PowerShell.Commands.PSUserAgent]::Chrome) -ErrorAction Stop
    }
    catch {
        throw "Loggin failed. Error: $($_.ToString())"
    }

    $LocationPayload = @{
                           clientContext = @{
                                appVersion = '1.0'
                                contextApp = 'com.icloud.web.fmf'
                                mapkitAvailable = $true
                                productType = 'fmfweb'
                                tileServer = 'Apple'
                                userInactivityTimeInMS = 20
                                windowInFocus = $true
                                windowVisible = $true
                            }
                        }

    $LocationPayloadJsonObj = $LocationPayload | ConvertTo-Json -Compress

   $LocationFetchHeaders = @{
                'Origin' = 'https://www.icloud.com'
                'Referer' = 'https://www.icloud.com/'
               }
    $LocationURI = "$($LoginData.webservices.fmf.url)/fmipservice/client/fmfweb/refreshClient?clientBuildNumber=$clientBuildNumber&clientId=$($LoginData.dsInfo.aDsID)&clientMasteringNumber=$clientMasteringNumber&dsid=$($LoginData.dsInfo.dsid)"

    $WaitingForLocationFix = $true
    $MaxTries = 5
    $AttemptNr = 0

    while ($WaitingForLocationFix -and $AttemptNr -lt $MaxTries) {
        $AttemptNr++

        $LocationPostResults = Invoke-RestMethod -Uri $LocationURI -Body $LocationPayloadJsonObj -Method Post -Headers $LocationFetchHeaders -WebSession $iCloudSession -UserAgent ([Microsoft.PowerShell.Commands.PSUserAgent]::Chrome)
        
        foreach ($iOSDevice in $LocationPostResults.content) {
            if ($iOSDevice.deviceStatus -ne 200) {
                Continue
            }

            if ($iOSDevice.location) {
                [PSCustomObject] @{
                                    DeviceName = $iOSDevice.name
                                    DeviceDisplayName = $iOSDevice.deviceDisplayName
                                    BatteryLevelPercent = [math]::Round($iOSDevice.batteryLevel*100)
                                    BatteryStatus = $iOSDevice.batteryStatus
                                    Longitude = $iOSDevice.location.longitude
                                    Latitude = $iOSDevice.location.latitude
                                    AllData = $iOSDevice
                                  }

                $WaitingForLocationFix = $false
            }
        }

        if ($WaitForLocationFix -eq $true -and $WaitingForLocationFix -eq $true) {
            Write-Warning 'Waiting for devices to be located...'
            Start-Sleep -Seconds 5
        }
        else {
            $WaitingForLocationFix = $false
        }
    }

    if ($WaitingForLocationFix) {
        throw "Timed out waiting for a location fix."
    }
}
