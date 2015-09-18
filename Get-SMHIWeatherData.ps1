
function Get-SMHIWeatherData
{
    [cmdletbinding()]
    param(
          [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$true)]
          $Latitude,
          [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$true)]
          $Longitude)

    BEGIN {
        $Data = $null
        $DailyForecast = $null
        $PreviousForecast = $null
    }

    PROCESS {

        $RoundedLong = [System.Math]::Round($Longitude,6)
        $RoundedLat = [System.Math]::Round($Latitude,6)

        $URL = "http://opendata-download-metfcst.smhi.se/api/category/pmp1.5g/version/1/geopoint/lat/$RoundedLat/lon/$RoundedLong/data.json"

        try {
            $Data = Invoke-RestMethod -Uri $URL -Method Get -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to get weather data from SMHI. The error was: $($Error[0])."
        }

        foreach ($DailyForecast in $Data.timeseries) {

            $PrecipitationCategory = switch ($DailyForecast.pcat)
            {
                      0 { "None" }
                      1 { "Snow" }
                      2 { "Snow and rain" }
                      3 { "Rain" }
                      4 { "Drizzle" }
                      5 { "Freezing rain" }
                      6 { "Freezing drizzle" }
                default { "Unknown" }
            }

            $returnObject = New-Object System.Object
            $returnObject | Add-Member -Type NoteProperty -Name Latitude -Value $Data.lon
            $returnObject | Add-Member -Type NoteProperty -Name Longitude -Value $Data.lat

            # Fix this for the first forecast
            if ($PreviousForecast -eq $null) {
                $returnObject | Add-Member -Type NoteProperty -Name ForecastStartDate -Value $(Get-Date $Data.referenceTime -Format "yyyy-MM-dd HH:mm:ss")
            }
            else {
                $returnObject | Add-Member -Type NoteProperty -Name ForecastStartDate -Value $(Get-Date $PreviousForecast -Format "yyyy-MM-dd HH:mm:ss")
            }

            $returnObject | Add-Member -Type NoteProperty -Name ForecastEndDate -Value $(Get-Date $DailyForecast.validTime -Format "yyyy-MM-dd HH:mm:ss")
            $returnObject | Add-Member -Type NoteProperty -Name Pressure -Value $DailyForecast.msl
            $returnObject | Add-Member -Type NoteProperty -Name Temperature -Value $DailyForecast.t
            $returnObject | Add-Member -Type NoteProperty -Name Visibility -Value $DailyForecast.vis
            $returnObject | Add-Member -Type NoteProperty -Name WindDirection -Value $DailyForecast.wd
            $returnObject | Add-Member -Type NoteProperty -Name WindVelocity -Value $DailyForecast.ws
            $returnObject | Add-Member -Type NoteProperty -Name RelativeHumidity -Value $DailyForecast.r
            $returnObject | Add-Member -Type NoteProperty -Name ThunderstormProbability -Value $DailyForecast.tstm
            $returnObject | Add-Member -Type NoteProperty -Name TotalCloudCover -Value $($DailyForecast.tcc*12.5)
            $returnObject | Add-Member -Type NoteProperty -Name LowCloudCover -Value $($DailyForecast.lcc*12.5)
            $returnObject | Add-Member -Type NoteProperty -Name MediumCloudCover -Value $($DailyForecast.mcc*12.5)
            $returnObject | Add-Member -Type NoteProperty -Name HighCloudCover -Value $($DailyForecast.hcc*12.5)
            $returnObject | Add-Member -Type NoteProperty -Name WindGust -Value $DailyForecast.gust
            $returnObject | Add-Member -Type NoteProperty -Name PrecipitationIntensityTotal -Value $DailyForecast.pit
            $returnObject | Add-Member -Type NoteProperty -Name PrecipitationIntensitySnow -Value $DailyForecast.pis
            $returnObject | Add-Member -Type NoteProperty -Name PrecipitationCategory -Value $PrecipitationCategory

            Write-Output $returnObject

            $PreviousForecast = $DailyForecast.validTime
        }
    }

    END { }
}
