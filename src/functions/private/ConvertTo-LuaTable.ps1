function ConvertTo-LuaTable {
    <#
        .SYNOPSIS
        Converts a PowerShell object to a Lua table string representation.

        .DESCRIPTION
        Recursively converts a PowerShell object (hashtable, array, PSCustomObject, or primitive)
        into a Lua table string. This is the internal serialization engine used by ConvertTo-Lua.
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        # The object to convert to a Lua table string.
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $InputObject,

        # The current indentation depth for formatting.
        [Parameter()]
        [int] $Depth = 0,

        # Number of spaces per indentation level.
        [Parameter()]
        [int] $IndentSize = 4,

        # Whether to compress the output (no newlines or indentation).
        [Parameter()]
        [switch] $Compress
    )

    begin {
        $indent = if ($Compress) { '' } else { ' ' * ($IndentSize * $Depth) }
        $childIndent = if ($Compress) { '' } else { ' ' * ($IndentSize * ($Depth + 1)) }
        $newline = if ($Compress) { '' } else { "`n" }
        $separator = if ($Compress) { ',' } else { ",`n" }
    }

    process {
        if ($null -eq $InputObject) {
            return 'nil'
        }

        if ($InputObject -is [bool]) {
            if ($InputObject) {
                return 'true'
            } else {
                return 'false'
            }
        }

        if ($InputObject -is [int] -or $InputObject -is [long] -or
            $InputObject -is [float] -or $InputObject -is [double] -or
            $InputObject -is [decimal] -or $InputObject -is [int16] -or
            $InputObject -is [int64] -or $InputObject -is [uint16] -or
            $InputObject -is [uint32] -or $InputObject -is [uint64] -or
            $InputObject -is [byte] -or $InputObject -is [sbyte] -or
            $InputObject -is [single]) {
            return $InputObject.ToString([System.Globalization.CultureInfo]::InvariantCulture)
        }

        if ($InputObject -is [string]) {
            $escaped = $InputObject -replace '\\', '\\' -replace '"', '\"' -replace "`n", '\n' -replace "`r", '\r' -replace "`t", '\t'
            return "`"$escaped`""
        }

        if ($InputObject -is [System.Collections.IList]) {
            if ($InputObject.Count -eq 0) {
                return '{}'
            }
            $items = [System.Collections.Generic.List[string]]::new()
            foreach ($item in $InputObject) {
                $value = ConvertTo-LuaTable -InputObject $item -Depth ($Depth + 1) -IndentSize $IndentSize -Compress:$Compress
                $items.Add("$childIndent$value")
            }
            return "{$newline$($items -join $separator)$newline$indent}"
        }

        # Handle hashtables and ordered dictionaries
        if ($InputObject -is [System.Collections.IDictionary]) {
            if ($InputObject.Count -eq 0) {
                return '{}'
            }
            $entries = [System.Collections.Generic.List[string]]::new()
            foreach ($key in $InputObject.Keys) {
                $value = ConvertTo-LuaTable -InputObject $InputObject[$key] -Depth ($Depth + 1) -IndentSize $IndentSize -Compress:$Compress
                $luaKey = Format-LuaKey -Key ([string]$key)
                $space = if ($Compress) { '' } else { ' ' }
                $entries.Add("$childIndent$luaKey$space=${space}$value")
            }
            return "{$newline$($entries -join $separator)$newline$indent}"
        }

        # Handle PSCustomObject (from ConvertFrom-Json etc.)
        if ($InputObject -is [psobject]) {
            $properties = $InputObject.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' }
            if (-not $properties) {
                return '{}'
            }
            $entries = [System.Collections.Generic.List[string]]::new()
            foreach ($prop in $properties) {
                $value = ConvertTo-LuaTable -InputObject $prop.Value -Depth ($Depth + 1) -IndentSize $IndentSize -Compress:$Compress
                $luaKey = Format-LuaKey -Key $prop.Name
                $space = if ($Compress) { '' } else { ' ' }
                $entries.Add("$childIndent$luaKey$space=${space}$value")
            }
            return "{$newline$($entries -join $separator)$newline$indent}"
        }

        # Fallback: convert to string
        $escaped = ($InputObject.ToString()) -replace '\\', '\\\\' -replace '"', '\"'
        return "`"$escaped`""
    }

    end {}
}
