function Read-LuaMultiLineString {
    <#
        .SYNOPSIS
        Reads a multi-line Lua string delimited by [[ and ]].
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param()

    begin {}

    process {
        $script:luaPos += 2 # skip [[
        $result = [System.Text.StringBuilder]::new()

        # Per Lua spec, a newline immediately after [[ is ignored
        if ($script:luaPos -lt $script:luaString.Length -and
            $script:luaString[$script:luaPos] -eq "`n") {
            $script:luaPos++
        } elseif ($script:luaPos + 1 -lt $script:luaString.Length -and
            $script:luaString[$script:luaPos] -eq "`r" -and
            $script:luaString[$script:luaPos + 1] -eq "`n") {
            $script:luaPos += 2
        }

        while ($script:luaPos + 1 -lt $script:luaString.Length) {
            if ($script:luaString[$script:luaPos] -eq ']' -and
                $script:luaString[$script:luaPos + 1] -eq ']') {
                $script:luaPos += 2
                return $result.ToString()
            }
            $null = $result.Append($script:luaString[$script:luaPos])
            $script:luaPos++
        }

        throw 'Unterminated multi-line string.'
    }

    end {}
}
