function Read-LuaMultiLineString {
    <#
        .SYNOPSIS
        Reads a multi-line Lua string delimited by long brackets [[ ]], [=[ ]=], [==[ ]==], etc.
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param()

    begin {}

    process {
        # Count the number of '=' characters in the opening long bracket
        $script:luaPos++ # skip first [
        $equalsCount = 0
        while ($script:luaPos -lt $script:luaString.Length -and
            $script:luaString[$script:luaPos] -eq '=') {
            $equalsCount++
            $script:luaPos++
        }
        if ($script:luaPos -ge $script:luaString.Length -or
            $script:luaString[$script:luaPos] -ne '[') {
            throw 'Invalid long bracket string opening.'
        }
        $script:luaPos++ # skip second [

        # Build the closing pattern: ] + N '=' + ]
        $closingBracket = ']' + ('=' * $equalsCount) + ']'
        $closeLen = $closingBracket.Length

        $result = [System.Text.StringBuilder]::new()

        # Per Lua spec, a newline immediately after the opening bracket is ignored
        if ($script:luaPos -lt $script:luaString.Length -and
            $script:luaString[$script:luaPos] -eq "`n") {
            $script:luaPos++
        } elseif ($script:luaPos + 1 -lt $script:luaString.Length -and
            $script:luaString[$script:luaPos] -eq "`r" -and
            $script:luaString[$script:luaPos + 1] -eq "`n") {
            $script:luaPos += 2
        }

        while ($script:luaPos -lt $script:luaString.Length) {
            if ($script:luaPos + $closeLen - 1 -lt $script:luaString.Length -and
                $script:luaString.Substring($script:luaPos, $closeLen) -eq $closingBracket) {
                $script:luaPos += $closeLen
                return $result.ToString()
            }
            $null = $result.Append($script:luaString[$script:luaPos])
            $script:luaPos++
        }

        throw 'Unterminated multi-line string.'
    }

    end {}
}
