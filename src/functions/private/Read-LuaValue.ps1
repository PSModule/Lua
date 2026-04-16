function Read-LuaValue {
    <#
        .SYNOPSIS
        Reads a single Lua value from the current parser position.
    #>
    [OutputType([object])]
    [OutputType([bool])]
    [OutputType([string])]
    [OutputType([int])]
    [OutputType([long])]
    [OutputType([double])]
    [CmdletBinding()]
    param()

    begin {}

    process {
        Skip-LuaWhitespace

        if ($script:luaPos -ge $script:luaString.Length) {
            throw 'Unexpected end of input'
        }

        $char = $script:luaString[$script:luaPos]

        # Table
        if ($char -eq '{') {
            return Read-LuaTable
        }

        # String (double-quoted)
        if ($char -eq '"') {
            return Read-LuaString -QuoteChar '"'
        }

        # String (single-quoted)
        if ($char -eq "'") {
            return Read-LuaString -QuoteChar "'"
        }

        # Multi-line string [[ ... ]] or [=[ ... ]=]
        if ($char -eq '[' -and
            $script:luaPos + 1 -lt $script:luaString.Length -and
            ($script:luaString[$script:luaPos + 1] -eq '[' -or
            $script:luaString[$script:luaPos + 1] -eq '=')) {
            return Read-LuaMultiLineString
        }

        # Number or negative number (including .5 style floats)
        if ($char -match '[0-9]' -or
            ($char -eq '.' -and
            $script:luaPos + 1 -lt $script:luaString.Length -and
            $script:luaString[$script:luaPos + 1] -match '[0-9]') -or
            ($char -eq '-' -and
            $script:luaPos + 1 -lt $script:luaString.Length -and
            $script:luaString[$script:luaPos + 1] -match '[0-9.]')) {
            return Read-LuaNumber
        }

        # Keywords and bare identifiers
        if ($char -match '[a-zA-Z_]') {
            $identStart = $script:luaPos
            while ($script:luaPos -lt $script:luaString.Length -and
                $script:luaString[$script:luaPos] -match '[a-zA-Z0-9_]') {
                $script:luaPos++
            }
            $ident = $script:luaString.Substring(
                $identStart,
                $script:luaPos - $identStart
            )

            switch ($ident) {
                'true' { return $true }
                'false' { return $false }
                'nil' { return $null }
                default {
                    throw "Unexpected bare identifier '$ident' at position $identStart."
                }
            }
        }

        throw "Unexpected character '$char' at position $($script:luaPos)."
    }

    end {}
}
