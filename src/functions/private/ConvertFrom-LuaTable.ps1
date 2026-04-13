function ConvertFrom-LuaTable {
    <#
        .SYNOPSIS
        Parses a Lua table string into a PowerShell object.

        .DESCRIPTION
        Takes a Lua table string and converts it to PowerShell hashtables, arrays,
        and primitive types. This is the internal parsing engine used by ConvertFrom-Lua.

        Supports:
        - Lua tables with string or identifier keys (converted to hashtables)
        - Lua arrays/sequences (converted to arrays)
        - Mixed tables (keys become hashtable entries, sequential values get numeric keys)
        - Strings (single and double quoted, with escape sequences)
        - Numbers (integers and floats)
        - Booleans (true/false)
        - nil (converted to $null)
        - Single-line comments (-- ...)
        - Multi-line comments (--[[ ... ]])
    #>
    [OutputType([object])]
    [CmdletBinding()]
    param(
        # The Lua table string to parse.
        [Parameter(Mandatory)]
        [string] $InputString,

        # Whether to output PSCustomObjects instead of hashtables.
        [Parameter()]
        [switch] $AsPSCustomObject
    )

    begin {}

    process {
        $script:luaString = $InputString
        $script:luaPos = 0
        $script:luaAsPSCustomObject = $AsPSCustomObject.IsPresent

        Skip-LuaWhitespace
        $result = Read-LuaValue

        return $result
    }

    end {}
}

function Skip-LuaWhitespace {
    <#
        .SYNOPSIS
        Advances the parser position past whitespace and comments.
    #>
    [CmdletBinding()]
    param()

    begin {}

    process {
        while ($script:luaPos -lt $script:luaString.Length) {
            $char = $script:luaString[$script:luaPos]

            # Skip whitespace
            if ($char -match '\s') {
                $script:luaPos++
                continue
            }

            # Skip comments
            if ($script:luaPos + 1 -lt $script:luaString.Length -and
                $script:luaString[$script:luaPos] -eq '-' -and
                $script:luaString[$script:luaPos + 1] -eq '-') {
                $script:luaPos += 2

                # Multi-line comment --[[ ... ]]
                if ($script:luaPos + 1 -lt $script:luaString.Length -and
                    $script:luaString[$script:luaPos] -eq '[' -and
                    $script:luaString[$script:luaPos + 1] -eq '[') {
                    $script:luaPos += 2
                    while ($script:luaPos + 1 -lt $script:luaString.Length) {
                        if ($script:luaString[$script:luaPos] -eq ']' -and
                            $script:luaString[$script:luaPos + 1] -eq ']') {
                            $script:luaPos += 2
                            break
                        }
                        $script:luaPos++
                    }
                } else {
                    # Single-line comment
                    while ($script:luaPos -lt $script:luaString.Length -and $script:luaString[$script:luaPos] -ne "`n") {
                        $script:luaPos++
                    }
                }
                continue
            }

            break
        }
    }

    end {}
}

function Read-LuaValue {
    <#
        .SYNOPSIS
        Reads a single Lua value from the current parser position.
    #>
    [OutputType([object])]
    [CmdletBinding()]
    param()

    begin {}

    process {
        Skip-LuaWhitespace

        if ($script:luaPos -ge $script:luaString.Length) {
            return $null
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

        # Multi-line string [[ ... ]]
        if ($char -eq '[' -and $script:luaPos + 1 -lt $script:luaString.Length -and
            $script:luaString[$script:luaPos + 1] -eq '[') {
            return Read-LuaMultiLineString
        }

        # Number or negative number
        if ($char -match '[0-9]' -or ($char -eq '-' -and $script:luaPos + 1 -lt $script:luaString.Length -and $script:luaString[$script:luaPos + 1] -match '[0-9]')) {
            return Read-LuaNumber
        }

        # Keywords: true, false, nil
        $remaining = $script:luaString.Substring($script:luaPos)
        if ($remaining -match '^true\b') {
            $script:luaPos += 4
            return $true
        }
        if ($remaining -match '^false\b') {
            $script:luaPos += 5
            return $false
        }
        if ($remaining -match '^nil\b') {
            $script:luaPos += 3
            return $null
        }

        throw "Unexpected character '$char' at position $($script:luaPos)."
    }

    end {}
}

function Read-LuaString {
    <#
        .SYNOPSIS
        Reads a quoted Lua string.
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [char] $QuoteChar
    )

    begin {}

    process {
        $script:luaPos++ # skip opening quote
        $result = [System.Text.StringBuilder]::new()

        while ($script:luaPos -lt $script:luaString.Length) {
            $char = $script:luaString[$script:luaPos]

            if ($char -eq '\') {
                $script:luaPos++
                if ($script:luaPos -ge $script:luaString.Length) {
                    throw 'Unexpected end of string after escape character.'
                }
                $nextChar = $script:luaString[$script:luaPos]
                switch ($nextChar) {
                    'n' { $null = $result.Append("`n") }
                    'r' { $null = $result.Append("`r") }
                    't' { $null = $result.Append("`t") }
                    '\' { $null = $result.Append('\') }
                    '"' { $null = $result.Append('"') }
                    "'" { $null = $result.Append("'") }
                    default { $null = $result.Append($nextChar) }
                }
                $script:luaPos++
                continue
            }

            if ($char -eq $QuoteChar) {
                $script:luaPos++ # skip closing quote
                return $result.ToString()
            }

            $null = $result.Append($char)
            $script:luaPos++
        }

        throw 'Unterminated string literal.'
    }

    end {}
}

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

        while ($script:luaPos + 1 -lt $script:luaString.Length) {
            if ($script:luaString[$script:luaPos] -eq ']' -and $script:luaString[$script:luaPos + 1] -eq ']') {
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

function Read-LuaNumber {
    <#
        .SYNOPSIS
        Reads a Lua number (integer or float).
    #>
    [OutputType([object])]
    [CmdletBinding()]
    param()

    begin {}

    process {
        $start = $script:luaPos
        $isFloat = $false

        if ($script:luaString[$script:luaPos] -eq '-') {
            $script:luaPos++
        }

        # Hex number
        if ($script:luaPos + 1 -lt $script:luaString.Length -and
            $script:luaString[$script:luaPos] -eq '0' -and
            $script:luaString[$script:luaPos + 1] -match '[xX]') {
            $script:luaPos += 2
            while ($script:luaPos -lt $script:luaString.Length -and $script:luaString[$script:luaPos] -match '[0-9a-fA-F]') {
                $script:luaPos++
            }
        } else {
            while ($script:luaPos -lt $script:luaString.Length -and $script:luaString[$script:luaPos] -match '[0-9]') {
                $script:luaPos++
            }
            if ($script:luaPos -lt $script:luaString.Length -and $script:luaString[$script:luaPos] -eq '.') {
                $isFloat = $true
                $script:luaPos++
                while ($script:luaPos -lt $script:luaString.Length -and $script:luaString[$script:luaPos] -match '[0-9]') {
                    $script:luaPos++
                }
            }
            # Scientific notation
            if ($script:luaPos -lt $script:luaString.Length -and $script:luaString[$script:luaPos] -match '[eE]') {
                $isFloat = $true
                $script:luaPos++
                if ($script:luaPos -lt $script:luaString.Length -and $script:luaString[$script:luaPos] -match '[+-]') {
                    $script:luaPos++
                }
                while ($script:luaPos -lt $script:luaString.Length -and $script:luaString[$script:luaPos] -match '[0-9]') {
                    $script:luaPos++
                }
            }
        }

        $numStr = $script:luaString.Substring($start, $script:luaPos - $start)
        if ($isFloat) {
            return [double]::Parse($numStr, [System.Globalization.CultureInfo]::InvariantCulture)
        }
        if ($numStr -match '^-?0[xX]') {
            return [int]::Parse($numStr.Substring($numStr.IndexOf('x') + 1), [System.Globalization.NumberStyles]::HexNumber)
        }
        $longValue = [long]0
        if ([long]::TryParse($numStr, [ref]$longValue)) {
            if ($longValue -ge [int]::MinValue -and $longValue -le [int]::MaxValue) {
                return [int]$longValue
            }
            return $longValue
        }
        return [double]::Parse($numStr, [System.Globalization.CultureInfo]::InvariantCulture)
    }

    end {}
}

function Read-LuaTable {
    <#
        .SYNOPSIS
        Reads a Lua table and returns either an array or hashtable.
    #>
    [OutputType([object])]
    [CmdletBinding()]
    param()

    begin {}

    process {
        $script:luaPos++ # skip {
        Skip-LuaWhitespace

        $entries = [System.Collections.Generic.List[object]]::new()
        $arrayValues = [System.Collections.Generic.List[object]]::new()
        $hasStringKeys = $false
        $hasArrayValues = $false

        while ($script:luaPos -lt $script:luaString.Length -and $script:luaString[$script:luaPos] -ne '}') {
            Skip-LuaWhitespace

            if ($script:luaPos -ge $script:luaString.Length -or $script:luaString[$script:luaPos] -eq '}') {
                break
            }

            # Check for bracket key: ["key"] = value
            if ($script:luaString[$script:luaPos] -eq '[') {
                $script:luaPos++ # skip [
                Skip-LuaWhitespace
                $key = Read-LuaValue
                Skip-LuaWhitespace
                if ($script:luaPos -lt $script:luaString.Length -and $script:luaString[$script:luaPos] -eq ']') {
                    $script:luaPos++ # skip ]
                }
                Skip-LuaWhitespace
                if ($script:luaPos -lt $script:luaString.Length -and $script:luaString[$script:luaPos] -eq '=') {
                    $script:luaPos++ # skip =
                }
                Skip-LuaWhitespace
                $value = Read-LuaValue
                $entries.Add(@{ Key = [string]$key; Value = $value })
                $hasStringKeys = $true
            }
            # Check for identifier key: key = value
            elseif ($script:luaString[$script:luaPos] -match '[a-zA-Z_]') {
                $identStart = $script:luaPos
                while ($script:luaPos -lt $script:luaString.Length -and $script:luaString[$script:luaPos] -match '[a-zA-Z0-9_]') {
                    $script:luaPos++
                }
                $ident = $script:luaString.Substring($identStart, $script:luaPos - $identStart)

                Skip-LuaWhitespace

                if ($script:luaPos -lt $script:luaString.Length -and $script:luaString[$script:luaPos] -eq '=') {
                    # Key = value pair
                    $script:luaPos++ # skip =
                    Skip-LuaWhitespace
                    $value = Read-LuaValue

                    $entries.Add(@{ Key = $ident; Value = $value })
                    $hasStringKeys = $true
                } else {
                    # Bare identifier as keyword value (true/false/nil)
                    $resolvedValue = switch ($ident) {
                        'true' { $true }
                        'false' { $false }
                        'nil' { $null }
                        default { $ident }
                    }
                    $arrayValues.Add($resolvedValue)
                    $hasArrayValues = $true
                }
            } else {
                # Array value
                $value = Read-LuaValue
                $arrayValues.Add($value)
                $hasArrayValues = $true
            }

            Skip-LuaWhitespace

            # Skip comma or semicolon separator
            if ($script:luaPos -lt $script:luaString.Length -and ($script:luaString[$script:luaPos] -eq ',' -or $script:luaString[$script:luaPos] -eq ';')) {
                $script:luaPos++
            }
        }

        if ($script:luaPos -lt $script:luaString.Length -and $script:luaString[$script:luaPos] -eq '}') {
            $script:luaPos++ # skip }
        }

        # Pure array (no string keys)
        if ($hasArrayValues -and -not $hasStringKeys) {
            return , [object[]]$arrayValues.ToArray()
        }

        # Build hashtable or PSCustomObject
        $table = [ordered]@{}
        $arrayIndex = 1
        foreach ($entry in $entries) {
            $table[$entry.Key] = $entry.Value
        }
        foreach ($value in $arrayValues) {
            $table[[string]$arrayIndex] = $value
            $arrayIndex++
        }

        if ($script:luaAsPSCustomObject) {
            return [pscustomobject]$table
        }
        return $table
    }

    end {}
}
