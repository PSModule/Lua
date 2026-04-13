function Read-LuaNumber {
    <#
        .SYNOPSIS
        Reads a Lua number (integer, float, hex, hex float, scientific notation).
    #>
    [OutputType([int])]
    [OutputType([long])]
    [OutputType([double])]
    [CmdletBinding()]
    param()

    begin {}

    process {
        $start = $script:luaPos
        $isFloat = $false
        $isHex = $false

        if ($script:luaString[$script:luaPos] -eq '-') {
            $script:luaPos++
        }

        # Hex number
        if ($script:luaPos + 1 -lt $script:luaString.Length -and
            $script:luaString[$script:luaPos] -eq '0' -and
            $script:luaString[$script:luaPos + 1] -match '[xX]') {
            $isHex = $true
            $script:luaPos += 2
            while ($script:luaPos -lt $script:luaString.Length -and
                $script:luaString[$script:luaPos] -match '[0-9a-fA-F]') {
                $script:luaPos++
            }
            # Hex float fractional part
            if ($script:luaPos -lt $script:luaString.Length -and
                $script:luaString[$script:luaPos] -eq '.') {
                $isFloat = $true
                $script:luaPos++
                while ($script:luaPos -lt $script:luaString.Length -and
                    $script:luaString[$script:luaPos] -match '[0-9a-fA-F]') {
                    $script:luaPos++
                }
            }
            # Hex float exponent (p/P)
            if ($script:luaPos -lt $script:luaString.Length -and
                $script:luaString[$script:luaPos] -match '[pP]') {
                $isFloat = $true
                $script:luaPos++
                if ($script:luaPos -lt $script:luaString.Length -and
                    $script:luaString[$script:luaPos] -match '[+-]') {
                    $script:luaPos++
                }
                while ($script:luaPos -lt $script:luaString.Length -and
                    $script:luaString[$script:luaPos] -match '[0-9]') {
                    $script:luaPos++
                }
            }
        } else {
            while ($script:luaPos -lt $script:luaString.Length -and
                $script:luaString[$script:luaPos] -match '[0-9]') {
                $script:luaPos++
            }
            if ($script:luaPos -lt $script:luaString.Length -and
                $script:luaString[$script:luaPos] -eq '.') {
                $isFloat = $true
                $script:luaPos++
                while ($script:luaPos -lt $script:luaString.Length -and
                    $script:luaString[$script:luaPos] -match '[0-9]') {
                    $script:luaPos++
                }
            }
            # Scientific notation
            if ($script:luaPos -lt $script:luaString.Length -and
                $script:luaString[$script:luaPos] -match '[eE]') {
                $isFloat = $true
                $script:luaPos++
                if ($script:luaPos -lt $script:luaString.Length -and
                    $script:luaString[$script:luaPos] -match '[+-]') {
                    $script:luaPos++
                }
                while ($script:luaPos -lt $script:luaString.Length -and
                    $script:luaString[$script:luaPos] -match '[0-9]') {
                    $script:luaPos++
                }
            }
        }

        $numStr = $script:luaString.Substring(
            $start, $script:luaPos - $start
        )

        if ($isFloat) {
            if ($isHex) {
                # Hex float like 0x1.fp10 - parse manually
                return [double](Read-LuaHexFloat -HexString $numStr)
            }
            return [double]::Parse(
                $numStr,
                [System.Globalization.CultureInfo]::InvariantCulture
            )
        }
        if ($isHex) {
            $isNegative = $numStr.StartsWith('-')
            $hexPart = if ($isNegative) {
                $numStr.Substring(3)
            } else {
                $numStr.Substring(2)
            }
            $longVal = [Convert]::ToInt64($hexPart, 16)
            if ($isNegative) { $longVal = -$longVal }
            if ($longVal -ge [int]::MinValue -and
                $longVal -le [int]::MaxValue) {
                return [int]$longVal
            }
            return $longVal
        }
        $longValue = [long]0
        if ([long]::TryParse($numStr, [ref]$longValue)) {
            if ($longValue -ge [int]::MinValue -and
                $longValue -le [int]::MaxValue) {
                return [int]$longValue
            }
            return $longValue
        }
        return [double]::Parse(
            $numStr,
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    }

    end {}
}
