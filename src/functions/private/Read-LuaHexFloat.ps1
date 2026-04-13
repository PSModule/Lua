function Read-LuaHexFloat {
    <#
        .SYNOPSIS
        Parses a Lua hex float string (e.g. 0x1.fp10) to a double.
    #>
    [OutputType([double])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $HexString
    )

    begin {}

    process {
        $isNegative = $HexString.StartsWith('-')
        $str = if ($isNegative) {
            $HexString.Substring(3)
        } else {
            $HexString.Substring(2)
        }

        $parts = $str -split '[pP]'
        $mantissaStr = $parts[0]
        $exponent = if ($parts.Length -gt 1) {
            [int]$parts[1]
        } else {
            0
        }

        $mantissaParts = $mantissaStr -split '\.'
        $intPart = if ($mantissaParts[0]) {
            [Convert]::ToInt64($mantissaParts[0], 16)
        } else {
            0
        }
        $fracValue = 0.0
        if ($mantissaParts.Length -gt 1 -and $mantissaParts[1]) {
            $fracStr = $mantissaParts[1]
            for ($i = 0; $i -lt $fracStr.Length; $i++) {
                $digitVal = [Convert]::ToInt32(
                    $fracStr[$i].ToString(), 16
                )
                $fracValue += $digitVal * [Math]::Pow(
                    16, - ($i + 1)
                )
            }
        }

        $result = ($intPart + $fracValue) * [Math]::Pow(2, $exponent)
        if ($isNegative) { $result = -$result }
        return $result
    }

    end {}
}
