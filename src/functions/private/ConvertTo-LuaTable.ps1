function ConvertTo-LuaTable {
    <#
        .SYNOPSIS
        Converts a PowerShell object to a Lua table string representation.

        .DESCRIPTION
        Recursively converts a PowerShell object (hashtable, array, PSCustomObject, or primitive)
        into a Lua table constructor string. This is the internal serialization engine used by ConvertTo-Lua.

        Uses fixed 4-space indentation per the Lua community convention.
        Properties with $null values are omitted (Lua nil-means-absent semantics).
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        # The object to convert to a Lua table string.
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $InputObject,

        # The current recursion depth.
        [Parameter()]
        [int] $CurrentDepth = 0,

        # Maximum allowed recursion depth.
        [Parameter()]
        [int] $MaxDepth = 2,

        # Whether to compress the output (no newlines or indentation).
        [Parameter()]
        [switch] $Compress,

        # Serialize enum values as their string name instead of numeric value.
        [Parameter()]
        [switch] $EnumsAsStrings
    )

    begin {
        $indent = if ($Compress) { '' } else { ' ' * (4 * $CurrentDepth) }
        $childIndent = if ($Compress) { '' } else { ' ' * (4 * ($CurrentDepth + 1)) }
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

        # Enum handling
        if ($InputObject -is [enum]) {
            if ($EnumsAsStrings) {
                $escaped = $InputObject.ToString() -replace '\\', '\\' -replace '"', '\"'
                return "`"$escaped`""
            }
            $underlyingType = [System.Enum]::GetUnderlyingType($InputObject.GetType())
            if ($underlyingType -eq [byte] -or
                $underlyingType -eq [uint16] -or
                $underlyingType -eq [uint32] -or
                $underlyingType -eq [uint64]) {
                return ([System.Convert]::ToUInt64($InputObject)).ToString([System.Globalization.CultureInfo]::InvariantCulture)
            }
            return ([System.Convert]::ToInt64($InputObject)).ToString([System.Globalization.CultureInfo]::InvariantCulture)
        }

        if ($InputObject -is [int] -or $InputObject -is [long] -or
            $InputObject -is [int16] -or $InputObject -is [int64] -or
            $InputObject -is [uint16] -or $InputObject -is [uint32] -or
            $InputObject -is [uint64] -or $InputObject -is [byte] -or
            $InputObject -is [sbyte]) {
            return $InputObject.ToString([System.Globalization.CultureInfo]::InvariantCulture)
        }

        if ($InputObject -is [double]) {
            if ([double]::IsNaN($InputObject) -or [double]::IsInfinity($InputObject)) {
                throw "Cannot serialize non-finite double value '$InputObject' to Lua. Lua numeric literals do not support NaN or Infinity."
            }
            return $InputObject.ToString([System.Globalization.CultureInfo]::InvariantCulture)
        }

        if ($InputObject -is [float] -or $InputObject -is [single]) {
            if ([single]::IsNaN($InputObject) -or [single]::IsInfinity($InputObject)) {
                throw "Cannot serialize non-finite single value '$InputObject' to Lua. Lua numeric literals do not support NaN or Infinity."
            }
            return $InputObject.ToString([System.Globalization.CultureInfo]::InvariantCulture)
        }

        if ($InputObject -is [decimal]) {
            return $InputObject.ToString([System.Globalization.CultureInfo]::InvariantCulture)
        }

        if ($InputObject -is [string]) {
            $escaped = $InputObject `
                -replace '\\', '\\' `
                -replace '"', '\"' `
                -replace "`0", '\0' `
                -replace "`a", '\a' `
                -replace "`b", '\b' `
                -replace "`f", '\f' `
                -replace "`n", '\n' `
                -replace "`r", '\r' `
                -replace "`t", '\t' `
                -replace "`v", '\v'
            return "`"$escaped`""
        }

        # Depth check for complex types
        if ($CurrentDepth -ge $MaxDepth) {
            Write-Warning "Depth limit ($MaxDepth) exceeded. Serializing remaining object as string."
            $str = $InputObject.ToString() `
                -replace '\\', '\\' `
                -replace '"', '\"' `
                -replace "`0", '\0' `
                -replace "`a", '\a' `
                -replace "`b", '\b' `
                -replace "`f", '\f' `
                -replace "`n", '\n' `
                -replace "`r", '\r' `
                -replace "`t", '\t' `
                -replace "`v", '\v'
            return "`"$str`""
        }

        if ($InputObject -is [System.Collections.IList]) {
            if ($InputObject.Count -eq 0) {
                return '{}'
            }
            $items = [System.Collections.Generic.List[string]]::new()
            foreach ($item in $InputObject) {
                $childParams = @{
                    InputObject    = $item
                    CurrentDepth   = $CurrentDepth + 1
                    MaxDepth       = $MaxDepth
                    Compress       = $Compress
                    EnumsAsStrings = $EnumsAsStrings
                }
                $value = ConvertTo-LuaTable @childParams
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
                $val = $InputObject[$key]
                # Omit $null values per Lua nil-means-absent semantics
                if ($null -eq $val) {
                    continue
                }
                $value = ConvertTo-LuaTable -InputObject $val `
                    -CurrentDepth ($CurrentDepth + 1) `
                    -MaxDepth $MaxDepth `
                    -Compress:$Compress `
                    -EnumsAsStrings:$EnumsAsStrings
                $luaKey = Format-LuaKey -Key ([string]$key)
                $space = if ($Compress) { '' } else { ' ' }
                $entries.Add("$childIndent$luaKey$space=${space}$value")
            }
            if ($entries.Count -eq 0) {
                return '{}'
            }
            return "{$newline$($entries -join $separator)$newline$indent}"
        }

        # Handle PSCustomObject
        if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
            $properties = $InputObject.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' }
            if (-not $properties) {
                return '{}'
            }
            $entries = [System.Collections.Generic.List[string]]::new()
            foreach ($prop in $properties) {
                # Omit $null values per Lua nil-means-absent semantics
                if ($null -eq $prop.Value) {
                    continue
                }
                $value = ConvertTo-LuaTable -InputObject $prop.Value `
                    -CurrentDepth ($CurrentDepth + 1) `
                    -MaxDepth $MaxDepth `
                    -Compress:$Compress `
                    -EnumsAsStrings:$EnumsAsStrings
                $luaKey = Format-LuaKey -Key $prop.Name
                $space = if ($Compress) { '' } else { ' ' }
                $entries.Add("$childIndent$luaKey$space=${space}$value")
            }
            if ($entries.Count -eq 0) {
                return '{}'
            }
            return "{$newline$($entries -join $separator)$newline$indent}"
        }

        # Fallback: convert to string
        $escaped = $InputObject.ToString() `
            -replace '\\', '\\' `
            -replace '"', '\"' `
            -replace "`0", '\0' `
            -replace "`a", '\a' `
            -replace "`b", '\b' `
            -replace "`f", '\f' `
            -replace "`n", '\n' `
            -replace "`r", '\r' `
            -replace "`t", '\t' `
            -replace "`v", '\v'
        return "`"$escaped`""
    }

    end {}
}
