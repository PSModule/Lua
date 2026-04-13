function ConvertFrom-LuaTable {
    <#
        .SYNOPSIS
        Parses a Lua table constructor string into a PowerShell object.

        .DESCRIPTION
        Takes a Lua table constructor string and converts it to PowerShell hashtables, arrays,
        and primitive types. This is the internal parsing engine used by ConvertFrom-Lua.

        Supports:
        - Lua tables with string or identifier keys (converted to hashtables or PSCustomObjects)
        - Lua arrays/sequences (converted to arrays)
        - Mixed tables (keys become hashtable entries, sequential values get numeric keys)
        - Strings (single and double quoted, multi-line, with all escape sequences per §3.1)
        - Numbers (integers, floats, hex, scientific notation, hex floats)
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
        [switch] $AsPSCustomObject,

        # Maximum allowed nesting depth.
        [Parameter()]
        [int] $MaxDepth = 1024
    )

    begin {}

    process {
        $script:luaString = $InputString
        $script:luaPos = 0
        $script:luaAsPSCustomObject = $AsPSCustomObject.IsPresent
        $script:luaMaxDepth = $MaxDepth
        $script:luaCurrentDepth = 0

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
        if ($char -match '[0-9]' -or ($char -eq '-' -and $script:luaPos + 1 -lt $script:luaString.Length -and $script:luaString[$script:luaPos + 1] -match '[0-9.]')) {
            return Read-LuaNumber
        }

        # Keywords and bare identifiers
        if ($char -match '[a-zA-Z_]') {
            $identStart = $script:luaPos
            while ($script:luaPos -lt $script:luaString.Length -and $script:luaString[$script:luaPos] -match '[a-zA-Z0-9_]') {
                $script:luaPos++
            }
            $ident = $script:luaString.Substring($identStart, $script:luaPos - $identStart)

            switch ($ident) {
                'true' { return $true }
                'false' { return $false }
                'nil' { return $null }
                default {
                    throw "Unexpected bare identifier '$ident' at position $identStart. Only true, false, and nil are valid in a data-only context."
                }
            }
        }

        throw "Unexpected character '$char' at position $($script:luaPos)."
    }

    end {}
}

function Read-LuaString {
    <#
        .SYNOPSIS
        Reads a quoted Lua string with full escape sequence support per §3.1.
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
                    'a' { $null = $result.Append([char]7) }   # bell
                    'b' { $null = $result.Append("`b") }      # backspace
                    'f' { $null = $result.Append([char]12) }   # form feed
                    'n' { $null = $result.Append("`n") }       # newline
                    'r' { $null = $result.Append("`r") }       # carriage return
                    't' { $null = $result.Append("`t") }       # tab
                    'v' { $null = $result.Append([char]11) }   # vertical tab
                    '\' { $null = $result.Append('\') }
                    '"' { $null = $result.Append('"') }
                    "'" { $null = $result.Append("'") }
                    '0' { $null = $result.Append([char]0) }    # null byte
                    'x' {
                        # \xXX - two hex digits
                        $script:luaPos++
                        if ($script:luaPos + 1 -lt $script:luaString.Length) {
                            $hexStr = $script:luaString.Substring($script:luaPos, 2)
                            $null = $result.Append([char][Convert]::ToInt32($hexStr, 16))
                            $script:luaPos += 2
                            continue
                        }
                        throw 'Invalid \x escape sequence.'
                    }
                    'u' {
                        # \u{XXXX} - Unicode code point
                        $script:luaPos++
                        if ($script:luaPos -lt $script:luaString.Length -and $script:luaString[$script:luaPos] -eq '{') {
                            $script:luaPos++
                            $hexStart = $script:luaPos
                            while ($script:luaPos -lt $script:luaString.Length -and $script:luaString[$script:luaPos] -ne '}') {
                                $script:luaPos++
                            }
                            $hexStr = $script:luaString.Substring($hexStart, $script:luaPos - $hexStart)
                            $codePoint = [Convert]::ToInt32($hexStr, 16)
                            $null = $result.Append([char]::ConvertFromUtf32($codePoint))
                            $script:luaPos++ # skip }
                            continue
                        }
                        throw 'Invalid \u escape sequence.'
                    }
                    default {
                        # \ddd - decimal byte sequence (1-3 digits)
                        if ($nextChar -match '[0-9]') {
                            $numStr = $nextChar.ToString()
                            $script:luaPos++
                            for ($d = 0; $d -lt 2; $d++) {
                                if ($script:luaPos -lt $script:luaString.Length -and $script:luaString[$script:luaPos] -match '[0-9]') {
                                    $numStr += $script:luaString[$script:luaPos]
                                    $script:luaPos++
                                } else {
                                    break
                                }
                            }
                            $null = $result.Append([char][int]$numStr)
                            continue
                        }
                        # Unknown escape - just pass through
                        $null = $result.Append($nextChar)
                    }
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

        # Per Lua spec, a newline immediately after [[ is ignored
        if ($script:luaPos -lt $script:luaString.Length -and $script:luaString[$script:luaPos] -eq "`n") {
            $script:luaPos++
        } elseif ($script:luaPos + 1 -lt $script:luaString.Length -and
            $script:luaString[$script:luaPos] -eq "`r" -and
            $script:luaString[$script:luaPos + 1] -eq "`n") {
            $script:luaPos += 2
        }

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
        Reads a Lua number (integer, float, hex, hex float, scientific notation).
    #>
    [OutputType([object])]
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
            while ($script:luaPos -lt $script:luaString.Length -and $script:luaString[$script:luaPos] -match '[0-9a-fA-F]') {
                $script:luaPos++
            }
            # Hex float fractional part
            if ($script:luaPos -lt $script:luaString.Length -and $script:luaString[$script:luaPos] -eq '.') {
                $isFloat = $true
                $script:luaPos++
                while ($script:luaPos -lt $script:luaString.Length -and $script:luaString[$script:luaPos] -match '[0-9a-fA-F]') {
                    $script:luaPos++
                }
            }
            # Hex float exponent (p/P)
            if ($script:luaPos -lt $script:luaString.Length -and $script:luaString[$script:luaPos] -match '[pP]') {
                $isFloat = $true
                $script:luaPos++
                if ($script:luaPos -lt $script:luaString.Length -and $script:luaString[$script:luaPos] -match '[+-]') {
                    $script:luaPos++
                }
                while ($script:luaPos -lt $script:luaString.Length -and $script:luaString[$script:luaPos] -match '[0-9]') {
                    $script:luaPos++
                }
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
            if ($isHex) {
                # Hex float like 0x1.fp10 — parse manually
                return [double](Read-LuaHexFloat -HexString $numStr)
            }
            return [double]::Parse($numStr, [System.Globalization.CultureInfo]::InvariantCulture)
        }
        if ($isHex) {
            $isNegative = $numStr.StartsWith('-')
            $hexPart = if ($isNegative) { $numStr.Substring(3) } else { $numStr.Substring(2) }
            $longVal = [Convert]::ToInt64($hexPart, 16)
            if ($isNegative) { $longVal = -$longVal }
            if ($longVal -ge [int]::MinValue -and $longVal -le [int]::MaxValue) {
                return [int]$longVal
            }
            return $longVal
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
        $str = if ($isNegative) { $HexString.Substring(3) } else { $HexString.Substring(2) }

        $parts = $str -split '[pP]'
        $mantissaStr = $parts[0]
        $exponent = if ($parts.Length -gt 1) { [int]$parts[1] } else { 0 }

        $mantissaParts = $mantissaStr -split '\.'
        $intPart = if ($mantissaParts[0]) { [Convert]::ToInt64($mantissaParts[0], 16) } else { 0 }
        $fracValue = 0.0
        if ($mantissaParts.Length -gt 1 -and $mantissaParts[1]) {
            $fracStr = $mantissaParts[1]
            for ($i = 0; $i -lt $fracStr.Length; $i++) {
                $digitVal = [Convert]::ToInt32($fracStr[$i].ToString(), 16)
                $fracValue += $digitVal * [Math]::Pow(16, -($i + 1))
            }
        }

        $result = ($intPart + $fracValue) * [Math]::Pow(2, $exponent)
        if ($isNegative) { $result = -$result }
        return $result
    }

    end {}
}

function Read-LuaTable {
    <#
        .SYNOPSIS
        Reads a Lua table and returns either an array, hashtable, or PSCustomObject.
    #>
    [OutputType([object])]
    [CmdletBinding()]
    param()

    begin {}

    process {
        $script:luaCurrentDepth++
        if ($script:luaCurrentDepth -gt $script:luaMaxDepth) {
            throw "Maximum nesting depth ($($script:luaMaxDepth)) exceeded at position $($script:luaPos)."
        }

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

            # Check for bracket key: ["key"] = value or [expr] = value
            if ($script:luaString[$script:luaPos] -eq '[' -and
                ($script:luaPos + 1 -lt $script:luaString.Length -and $script:luaString[$script:luaPos + 1] -ne '[')) {
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
                    # Bare identifier as keyword value (true/false/nil) or error
                    switch ($ident) {
                        'true' { $arrayValues.Add($true) }
                        'false' { $arrayValues.Add($false) }
                        'nil' { $arrayValues.Add($null) }
                        default {
                            throw "Unexpected bare identifier '$ident' at position $identStart. Only true, false, and nil are valid in a data-only context."
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

            # Skip comma or semicolon separator
            if ($script:luaPos -lt $script:luaString.Length -and ($script:luaString[$script:luaPos] -eq ',' -or $script:luaString[$script:luaPos] -eq ';')) {
                $script:luaPos++
            }
        }

        if ($script:luaPos -lt $script:luaString.Length -and $script:luaString[$script:luaPos] -eq '}') {
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
