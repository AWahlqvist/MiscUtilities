function Get-AppleDeviceLocation
{
    [cmdletbinding()]
    param(
          [Parameter(Mandatory=$true)]
          [System.Management.Automation.PSCredential] $Credential,
          [switch] $WaitForLocationFix = $true)

    $clientBuildNumber = '15D108'
    $clientId = '000110-10-861fd091-b128-4525-8023-7f1ee59cff89'


    $LoginUri = "https://setup.icloud.com/setup/ws/1/login?clientBuildNumber=$clientBuildNumber&clientId=$clientId"


    $LoginParameters = @{
                            clientBuildNumber = $clientBuildNumber
                            clientId = $clientId
                        }

    $PayloadHash = @{
                        apple_id = $Credential.UserName
                        extended_login = $false
                        password = $Credential.GetNetworkCredential().Password
                    }

    $PayloadJsonObj = $PayloadHash | ConvertTo-Json

    $Header = @{
                'Origin' = 'https://www.icloud.com'
                'Referer' = 'https://www.icloud.com'
               }


    $LoginData = Invoke-RestMethod -Uri $LoginUri -Body $PayloadJsonObj -Headers $Header -Method Post -SessionVariable iCloudSession -UserAgent ([Microsoft.PowerShell.Commands.PSUserAgent]::Chrome)

    $FindMyiPhoneURI = "https://p02-fmipweb.icloud.com/fmipservice/client/web/refreshClient?clientBuildNumber=$clientBuildNumber&clientId=$($LoginData.dsInfo.aDsID)&dsid=$($LoginData.dsInfo.dsid)"
    # $FindMyiPhoneURI = "https://p02-fmipweb.icloud.com/fmipservice/client/web/refreshClient?clientBuildNumber=$clientBuildNumber&clientId=$clientId&dsid=$($LoginData.dsInfo.dsid)"

    $LocationPayload = @{
                           clientContext = @{
                                apiVersion = '3.0'
                                appName = 'iCloud Find (Web)'
                                appVersion = '2.0'
                                fmly = $true
                                inactiveTime = '2191'
                                timezone = 'Europe/Stockholm'
                            }
                        }

    $LocationPayloadJsonObj = $LocationPayload | ConvertTo-Json

    $WaitingForLocationFix = $true

    while ($WaitingForLocationFix) {

        $LocationPostResults = Invoke-RestMethod -Uri $FindMyiPhoneURI -Body $LocationPayloadJsonObj -Method Post -WebSession $iCloudSession -UserAgent ([Microsoft.PowerShell.Commands.PSUserAgent]::Chrome)
        
        foreach ($iOSDevice in $LocationPostResults.content) {
            if ($iOSDevice.location) {
                [PSCustomObject] @{
                                    DeviceName = $iOSDevice.name
                                    DeviceDisplayName = $iOSDevice.deviceDisplayName
                                    BatteryLevel = $iOSDevice.batteryLevel
                                    BatteryStatus = $iOSDevice.batteryStatus
                                    Longitude = $iOSDevice.location.longitude
                                    Latitude = $iOSDevice.location.latitude
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
}
