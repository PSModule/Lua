function Read-LuaTable {
    <#
        .SYNOPSIS
        Reads a Lua table constructor and returns an array, hashtable,
        or PSCustomObject.
    #>
    [OutputType([object[]])]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param()

    begin {}

    process {
        $script:luaCurrentDepth++
        if ($script:luaCurrentDepth -gt $script:luaMaxDepth) {
            throw "Maximum nesting depth ($($script:luaMaxDepth)) exceeded."
        }

        $script:luaPos++ # skip {
        Skip-LuaWhitespace

        $entries = [System.Collections.Generic.List[object]]::new()
        $arrayValues = [System.Collections.Generic.List[object]]::new()
        $hasStringKeys = $false
        $hasArrayValues = $false

        while ($script:luaPos -lt $script:luaString.Length -and
            $script:luaString[$script:luaPos] -ne '}') {
            Skip-LuaWhitespace

            if ($script:luaPos -ge $script:luaString.Length -or
                $script:luaString[$script:luaPos] -eq '}') {
                break
            }

            # Check for bracket key: ["key"] = value or [expr] = value
            # When [ is followed by [ or =, it's a long-bracket string value, not a bracket key
            if ($script:luaString[$script:luaPos] -eq '[' -and
                $script:luaPos + 1 -lt $script:luaString.Length -and
                $script:luaString[$script:luaPos + 1] -ne '[' -and
                $script:luaString[$script:luaPos + 1] -ne '=') {
                $script:luaPos++ # skip [
                Skip-LuaWhitespace
                $key = Read-LuaValue
                if ($null -eq $key) {
                    throw 'Lua table keys cannot be nil.'
                }
                Skip-LuaWhitespace
                if ($script:luaPos -ge $script:luaString.Length -or
                    $script:luaString[$script:luaPos] -ne ']') {
                    throw "Expected ']' after bracket key in Lua table."
                }
                $script:luaPos++ # skip ]
                Skip-LuaWhitespace
                if ($script:luaPos -ge $script:luaString.Length -or
                    $script:luaString[$script:luaPos] -ne '=') {
                    throw "Expected '=' after bracket key in Lua table."
                }
                $script:luaPos++ # skip =
                Skip-LuaWhitespace
                $value = Read-LuaValue
                $entries.Add(@{ Key = [string]$key; Value = $value })
                $hasStringKeys = $true
            } elseif ($script:luaString[$script:luaPos] -match '[a-zA-Z_]') {
                # Check for identifier key: key = value
                $identStart = $script:luaPos
                while ($script:luaPos -lt $script:luaString.Length -and
                    $script:luaString[$script:luaPos] -match '[a-zA-Z0-9_]') {
                    $script:luaPos++
                }
                $ident = $script:luaString.Substring(
                    $identStart, $script:luaPos - $identStart
                )

                Skip-LuaWhitespace

                if ($script:luaPos -lt $script:luaString.Length -and
                    $script:luaString[$script:luaPos] -eq '=') {
                    # Key = value pair
                    $script:luaPos++ # skip =
                    Skip-LuaWhitespace
                    $value = Read-LuaValue
                    $entries.Add(@{
                            Key   = $ident
                            Value = $value
                        })
                    $hasStringKeys = $true
                } else {
                    # Bare identifier as keyword value
                    switch ($ident) {
                        'true' { $arrayValues.Add($true) }
                        'false' { $arrayValues.Add($false) }
                        'nil' { $arrayValues.Add($null) }
                        default {
                            throw "Unexpected bare identifier '$ident'."
                        }
                    }
                    $hasArrayValues = $true
                }
            } else {
                # Array value
                $value = Read-LuaValue
                $arrayValues.Add($value)
                $hasArrayValues = $true
            }

            Skip-LuaWhitespace

            # Lua requires a comma or semicolon between fields unless the next token is }
            if ($script:luaPos -lt $script:luaString.Length) {
                if ($script:luaString[$script:luaPos] -eq ',' -or
                    $script:luaString[$script:luaPos] -eq ';') {
                    $script:luaPos++
                } elseif ($script:luaString[$script:luaPos] -ne '}') {
                    throw "Expected ',', ';', or '}' in Lua table constructor."
                }
            }
        }

        if ($script:luaPos -lt $script:luaString.Length -and
            $script:luaString[$script:luaPos] -eq '}') {
            $script:luaPos++ # skip }
        }

        $script:luaCurrentDepth--

        # Pure array (no string keys)
        if ($hasArrayValues -and -not $hasStringKeys) {
            return , [object[]]$arrayValues.ToArray()
        }

        # Empty table
        if (-not $hasArrayValues -and -not $hasStringKeys) {
            if ($script:luaAsPSCustomObject) {
                return [pscustomobject]@{}
            }
            return [ordered]@{}
        }

        # Build ordered hashtable (or PSCustomObject)
        $table = [ordered]@{}
        foreach ($entry in $entries) {
            $table[$entry.Key] = $entry.Value
        }
        # Mixed table: sequential values get integer keys starting at 1
        $arrayIndex = 1
        foreach ($val in $arrayValues) {
            $table[[string]$arrayIndex] = $val
            $arrayIndex++
        }

        if ($script:luaAsPSCustomObject) {
            return [pscustomobject]$table
        }
        return $table
    }

    end {}
}
