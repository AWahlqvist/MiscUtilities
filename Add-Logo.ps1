function Add-Logo
{

    <#
    .SYNOPSIS
    This function can add a logotype to another picture

    .DESCRIPTION
    This function can be used to place a picture (usually a logo) on top of
    another picture. You can either just place it in the same corner/position
    on each one, or use the "Dynamic logo placement" functionality to let the
    function calculate the best possible placement (out of the four corners).

    That calculation is done by calculating the contrast and "how much is
    going on" in every corner (number of different colors).

    You can set the accurancy (number of sampled pictures) to your liking,
    but it will be painfully slow on big pictures if you set it too high.

    .PARAMETER BackgroundPictureFile
    The path to the picture file that should be used as a background

    .PARAMETER LogoPictureFile
    The path to the logo picture file

    .PARAMETER OutPath
    Where to place the resulting file

    .PARAMETER LogoPlacement
    The corner where the logo should be placed

    .PARAMETER DynamicLogoPlacement
    Specify this switch if you want the function to calculate the best
    possible corner for the logo (see Description of this function)

    .PARAMETER DynamicPlacementAccuracy
    This decides how many pixels will be sampled before placing the logo.

    The higher value the better the accuracy, but it will be slower.

    .PARAMETER MinimumContrast
    This value set the minimum acceptable contrast when placing the logo

    .PARAMETER MaxColorSpan
    This value set the maximum allowed color span of the background where
    the logo will be placed. Can be used to force the placement to a corner
    where things are a bit more "calm".

    .PARAMETER HorisontalDisplacementFactor
    Sets the position of the logo relative to the edge (horisontal)

    .PARAMETER VerticalDisplacementFactor
    Sets the position of the logo relative to the edge (vertical)

    .PARAMETER ProportionFactor
    Use this value to scale the logo relative to the background picture
    size

    .EXAMPLE
    Add-Logo -LogoPictureFile .\Logo.png -BackgroundPictureFile .\Background.jpg -DynamicLogoPlacement

    Will place the picture "Logo.png" on the background 'Background.jpg' and save the results as a new file.

    .EXAMPLE
    gci *.jpg | Add-Logo -LogoPictureFile .\Logo.png -OutPath .\PicturesWithLogos -DynamicLogoPlacement

    Will place the picture 'Logo.png' on all the jpg-files piped to the function and output them to the
    'PicturesWithLogos' folder.

    #>

    [cmdletbinding(DefaultParameterSetName='StaticLogoPlacement')]
    Param(
        [Parameter(Mandatory=$True, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias('Fullname')]
        [string] $BackgroundPictureFile,
        [Parameter(Mandatory=$True)]
        [string] $LogoPictureFile,
        [string] $OutPath,
        [Parameter(Mandatory=$false, ParameterSetName='StaticLogoPlacement')]
        [ValidateSet('TopLeft','TopRight','BottomLeft','BottomRight')]
        [string] $LogoPlacement = 'BottomRight',
        [Parameter(Mandatory=$false, ParameterSetName='DynamicLogoPlacement')]
        [switch] $DynamicLogoPlacement,
        [Parameter(Mandatory=$false, ParameterSetName='DynamicLogoPlacement')]
        [ValidateRange(0,100)]
        [int] $DynamicPlacementAccuracy = 10,
        [Parameter(Mandatory=$false, ParameterSetName='DynamicLogoPlacement')]
        [int] $MinimumContrast = 150,
        [Parameter(Mandatory=$false, ParameterSetName='DynamicLogoPlacement')]
        [ValidateRange(0,768)]
        [int] $MaxColorSpan = 650,
        [decimal] $HorisontalDisplacementFactor = 5,
        [decimal] $VerticalDisplacementFactor = 5,
        [decimal] $ProportionFactor = 6.0
        )


    BEGIN {
        [reflection.assembly]::LoadWithPartialName('System.Drawing') | Out-Null
    }

    PROCESS {

        $OutFilePath = Get-ChildItem $BackgroundPictureFile
        $LogoFileName = Get-ChildItem $LogoPictureFile

        $BackgroundPicture = New-Object System.Drawing.Bitmap (Resolve-Path $BackgroundPictureFile).Path
        $LogoPicture = New-Object System.Drawing.Bitmap (Resolve-Path $LogoPictureFile).Path

        [decimal] $LogoSizeFactor = $BackgroundPicture.Width/$ProportionFactor/$LogoPicture.Width
        $LogoWidth = $LogoPicture.Width * $LogoSizeFactor
        $LogoHeight = $LogoPicture.Height * $LogoSizeFactor
        [decimal] $HorisontalDisplacement = $BackgroundPicture.Width*($HorisontalDisplacementFactor/100)
        [decimal] $VerticalDisplacement = $BackgroundPicture.Height*($VerticalDisplacementFactor/100)
        

        if ($BackgroundPicture.PixelFormat -like '*Indexed') {
            $NewBackgroundPicture = New-Object System.Drawing.Bitmap $BackgroundPicture.Width,$BackgroundPicture.Height
        }
        else {
            $NewBackgroundPicture = $BackgroundPicture.Clone()
        }

        $NewPictureDrawing = [System.Drawing.Graphics]::FromImage($NewBackgroundPicture)

        $NewPictureDrawing.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $NewPictureDrawing.DrawImage($BackgroundPicture, 0, 0)

        if ($DynamicLogoPlacement) {
            $SolidLogoPixels = @()

            for ($HorisontalLogoPixel = 0; $HorisontalLogoPixel -lt ($LogoPicture.Width); $HorisontalLogoPixel = [Math]::Round($HorisontalLogoPixel+$LogoPicture.Width/(($LogoPicture.Width * $DynamicPlacementAccuracy)/100))) {

                for ($VerticalLogoPixel = 0; $VerticalLogoPixel -lt ($LogoPicture.Height); $VerticalLogoPixel = [Math]::Round($VerticalLogoPixel+$LogoPicture.Height/(($LogoPicture.Height * $DynamicPlacementAccuracy)/100))) {
                    $SolidLogoPixels += $LogoPicture.GetPixel($HorisontalLogoPixel, $VerticalLogoPixel) | Where-Object { $_.A -ne 0 }
                }
            }

            $PossiblePlacements = 'BottomLeft', 'BottomRight', 'TopRight', 'TopLeft'
            $PlacementsAndContrasts = @()

            foreach ($PossiblePlacement in $PossiblePlacements) {

                switch ($PossiblePlacement) {
                    'TopLeft' { $VerticalPlacement = 0+$VerticalDisplacement ; $HorizontalPlacement = 0+$HorisontalDisplacement }
                    'TopRight' { $VerticalPlacement = 0+$VerticalDisplacement ; $HorizontalPlacement = $BackgroundPicture.Width-($LogoWidth+$HorisontalDisplacement) }
                    'BottomLeft' { $VerticalPlacement = $BackgroundPicture.Height-($LogoHeight+$VerticalDisplacement) ; $HorizontalPlacement = 0+$HorisontalDisplacement }
                    'BottomRight' { $VerticalPlacement = $BackgroundPicture.Height-($LogoHeight+$VerticalDisplacement) ; $HorizontalPlacement = $BackgroundPicture.Width-($LogoWidth+$HorisontalDisplacement) }
                }

                $SolidLogoPixels = $SolidLogoPixels | Select-Object -Unique

                [long] $TotalContrast = 0
                $DifferentColorsInBackground = @()
                [long] $NumberOfPixelsCompared = 0
                for ($HorisontalPlacementPixel = $HorizontalPlacement; $HorisontalPlacementPixel -lt ($HorizontalPlacement+$LogoWidth); $HorisontalPlacementPixel = [Math]::Round($HorisontalPlacementPixel + $LogoWidth/(($LogoWidth * $DynamicPlacementAccuracy)/100))) {

                    for ($VerticalPlacementPixel = $VerticalPlacement; $VerticalPlacementPixel -lt ($VerticalPlacement+$LogoHeight); $VerticalPlacementPixel = [Math]::Round($VerticalPlacementPixel + $LogoHeight/(($LogoHeight * $DynamicPlacementAccuracy)/100))) {
                        $BackgroundPicturePixel = $BackgroundPicture.GetPixel($HorisontalPlacementPixel, $VerticalPlacementPixel)
                        $DifferentColorsInBackground += $BackgroundPicturePixel.Name

                        foreach ($SolidLogoPixel in $SolidLogoPixels) {
                            $NumberOfPixelsCompared++
                            $RedContrast = [Math]::Abs($BackgroundPicturePixel.R-$SolidLogoPixel.R)
                            $GreenContrast = [Math]::Abs($BackgroundPicturePixel.G-$SolidLogoPixel.G)
                            $BlueContrast = [Math]::Abs($BackgroundPicturePixel.B-$SolidLogoPixel.B)

                            $CalculatedContrast = $RedContrast + $GreenContrast + $BlueContrast
                            $TotalContrast += $CalculatedContrast
                        }
                    }
                }

                $RedColorSpace = $DifferentColorsInBackground | % { [Convert]::ToInt32(($_.SubString(2,2)),16) } | Measure-Object -Minimum -Maximum
                $GreenColorSpace = $DifferentColorsInBackground | % { [Convert]::ToInt32(($_.SubString(4,2)),16) } | Measure-Object -Minimum -Maximum
                $BlueColorSpace = $DifferentColorsInBackground | % { [Convert]::ToInt32(($_.SubString(6,2)),16) } | Measure-Object -Minimum -Maximum

                $RedColorSpaceSpan = $RedColorSpace.Maximum - $RedColorSpace.Minimum
                $GreenColorSpaceSpan = $GreenColorSpace.Maximum - $GreenColorSpace.Minimum
                $BlueColorSpaceSpan = $BlueColorSpace.Maximum - $BlueColorSpace.Minimum

                $ColorSpaceSpan = $RedColorSpaceSpan + $GreenColorSpaceSpan + $BlueColorSpaceSpan
                $ContrastValuePerPixel = [Math]::Round($TotalContrast/$NumberOfPixelsCompared)

                $PlacementData = New-Object System.Object
                $PlacementData | Add-Member -Type NoteProperty -Name Placement -Value $PossiblePlacement
                $PlacementData | Add-Member -Type NoteProperty -Name TotalContrast -Value $TotalContrast
                $PlacementData | Add-Member -Type NoteProperty -Name ContrastValuePerPixel -Value $ContrastValuePerPixel
                $PlacementData | Add-Member -Type NoteProperty -Name NumberOfPixelsCompared -Value $NumberOfPixelsCompared
                $PlacementData | Add-Member -Type NoteProperty -Name ColorSpaceSpan -Value $ColorSpaceSpan

                
                $PlacementsAndContrasts += $PlacementData

                Remove-Variable ColorSpaceSpan,
                                TotalContrast,
                                ContrastValuePerPixel,
                                RedContrast,
                                GreenContrast,
                                BlueContrast,
                                CalculatedContrast,
                                ColorSpaceSpan,
                                RedColorSpaceSpan,
                                RedColorSpace,
                                GreenColorSpaceSpan,
                                GreenColorSpace,
                                BlueColorSpace,
                                BlueColorSpaceSpan -ErrorAction SilentlyContinue
            }

            $QualifiedPlacements = $PlacementsAndContrasts | Where-Object { [int] $_.ContrastValuePerPixel -ge $MinimumContrast -AND [int] $_.ColorSpaceSpan -le $MaxColorSpan }
            $BestContrast = $QualifiedPlacements | Sort-Object { [int] $_.ContrastValuePerPixel } -Descending | Select-Object -First 1
            $MostSolidColor = $QualifiedPlacements | Sort-Object { [int] $_.ColorSpaceSpan } | Select-Object -First 1

            if (!$QualifiedPlacements) {
                $BestContrast = $PlacementsAndContrasts | Sort-Object { [int] $_.ContrastValuePerPixel -gt $MinimumContrast } -Descending | Select-Object -First 1
                $MostSolidColor = $PlacementsAndContrasts | Sort-Object { [int] $_.ColorSpaceSpan } | Select-Object -First 1
                Write-Error "Couldn't find a corner with a minimum contrast of $MinimumContrast and/or max color span of $MaxColorSpan. Highest contrast corner: $($BestContrast.Placement) (Contrast: $($BestContrast.ContrastValuePerPixel). Colorspan: $($BestContrast.ColorSpaceSpan)). Most solid color corner: $($MostSolidColor.Placement) (Contrast: $($MostSolidColor.ContrastValuePerPixel). Colorspan: $($MostSolidColor.ColorSpaceSpan)). File: $BackgroundPictureFile"
                return
            }

            if ($MostSolidColor.ColorSpaceSpan -ne $BestContrast.ColorSpaceSpan) {
                $BetterColorConditionsInPercent = ($BestContrast.ColorSpaceSpan - $MostSolidColor.ColorSpaceSpan)/$BestContrast.ColorSpaceSpan*100
            }
            else {
                $BetterColorConditionsInPercent = 0
            }
            
            if ($MostSolidColor.ContrastValuePerPixel -ne $BestContrast.ContrastValuePerPixel) {
                $BetterContrastConditionsInPercent = ($BestContrast.ContrastValuePerPixel-$MostSolidColor.ContrastValuePerPixel)/$MostSolidColor.ContrastValuePerPixel*100
            }
            else {
                $BetterContrastConditionsInPercent = 0
            }

            Write-Verbose "Highest contrast corner: $($BestContrast.Placement) (Contrast: $($BestContrast.ContrastValuePerPixel). Colorspan: $($BestContrast.ColorSpaceSpan)). Most solid color corner: $($MostSolidColor.Placement) (Contrast: $($MostSolidColor.ContrastValuePerPixel). Colorspan: $($MostSolidColor.ColorSpaceSpan)). Contrast advantage: $([Math]::Round($BetterContrastConditionsInPercent)) %. Color advantage: $([Math]::Round($BetterColorConditionsInPercent)) %. Original file: $BackgroundPictureFile"

            # Solid colors usually means more than contrast
            # when the contrast value is fulfilled.
            # But if it's just a little, we should go with contrast
            # instead if that difference is big.

            if ($BetterColorConditionsInPercent -gt 40 -AND $BetterContrastConditionsInPercent -lt 100) {
                $BestLogoPlacement = $MostSolidColor.Placement
            }
            elseif ($BetterContrastConditionsInPercent -gt 100 -AND $BetterColorConditionsInPercent -lt 40) {
                $BestLogoPlacement = $BestContrast.Placement
            }
            elseif ($BetterContrastConditionsInPercent -gt $BetterColorConditionsInPercent -AND $BetterColorConditionsInPercent -lt 20) {
                $BestLogoPlacement = $BestContrast.Placement
            }
            else {
                $BestLogoPlacement = $MostSolidColor.Placement
            }

            Write-Verbose "The best placement for the logo is in the `"$BestLogoPlacement`" corner"

            switch ($BestLogoPlacement) {
                'TopLeft' { $VerticalPlacement = 0+$VerticalDisplacement ; $HorizontalPlacement = 0+$HorisontalDisplacement }
                'TopRight' { $VerticalPlacement = 0+$VerticalDisplacement ; $HorizontalPlacement = $BackgroundPicture.Width-($LogoWidth+$HorisontalDisplacement) }
                'BottomLeft' { $VerticalPlacement = $BackgroundPicture.Height-($LogoHeight+$VerticalDisplacement) ; $HorizontalPlacement = 0+$HorisontalDisplacement }
                'BottomRight' { $VerticalPlacement = $BackgroundPicture.Height-($LogoHeight+$VerticalDisplacement) ; $HorizontalPlacement = $BackgroundPicture.Width-($LogoWidth+$HorisontalDisplacement) }
            }

            if ($OutPath -eq '') {
                $OutFileFullPath = "$($OutFilePath.Directory)\$($OutFilePath.BaseName)-$($LogoFileName.BaseName)-$BestLogoPlacement$($OutFilePath.Extension)"
            }
            else {
                $OutFileFullPath = Join-Path $OutPath "\$($OutFilePath.BaseName)-$($LogoFileName.BaseName)-$BestLogoPlacement$($OutFilePath.Extension)"
            }

            Remove-Variable BestLogoPlacement, BestContrast, QualifiedPlacements, MostSolidColor, BetterColorConditionsInPercent, BetterContrastConditionsInPercent -ErrorAction SilentlyContinue
        }
        else {
            switch ($LogoPlacement) {
                'TopLeft' { $VerticalPlacement = 0+$VerticalDisplacement ; $HorizontalPlacement = 0+$HorisontalDisplacement }
                'TopRight' { $VerticalPlacement = 0+$VerticalDisplacement ; $HorizontalPlacement = $BackgroundPicture.Width-($LogoWidth+$HorisontalDisplacement) }
                'BottomLeft' { $VerticalPlacement = $BackgroundPicture.Height-($LogoHeight+$VerticalDisplacement) ; $HorizontalPlacement = 0+$HorisontalDisplacement }
                'BottomRight' { $VerticalPlacement = $BackgroundPicture.Height-($LogoHeight+$VerticalDisplacement) ; $HorizontalPlacement = $BackgroundPicture.Width-($LogoWidth+$HorisontalDisplacement) }
            }

            if ($OutPath -eq '') {
                $OutFileFullPath = "$($OutFilePath.Directory)\$($OutFilePath.BaseName)-$($LogoFileName.BaseName)-$LogoPlacement$($OutFilePath.Extension)"
            }
            else {
                $OutFileFullPath = Join-Path $OutPath "\$($OutFilePath.BaseName)-$($LogoFileName.BaseName)-$LogoPlacement$($OutFilePath.Extension)"
            }
        }

        $NewPictureDrawing.DrawImage($LogoPicture, $HorizontalPlacement, $VerticalPlacement, $LogoWidth, $LogoHeight)

        $SavePath = Join-Path -Path (Resolve-Path (Split-Path $OutFileFullPath -Parent)).Path -ChildPath (Split-Path $OutFileFullPath -Leaf)
        $NewBackgroundPicture.Save($SavePath,([system.drawing.imaging.imageformat]::Jpeg))

        $BackgroundPicture.Dispose()
        $LogoPicture.Dispose()
        $NewBackgroundPicture.Dispose()
    }
    END { }
}
