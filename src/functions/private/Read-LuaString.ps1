function Read-LuaString {
    <#
        .SYNOPSIS
        Reads a quoted Lua string with escape sequence support per Lua 5.4 §3.1.
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
                    'a' {
                        $null = $result.Append([char]7)
                        $script:luaPos++
                    }
                    'b' {
                        $null = $result.Append("`b")
                        $script:luaPos++
                    }
                    'f' {
                        $null = $result.Append([char]12)
                        $script:luaPos++
                    }
                    'n' {
                        $null = $result.Append("`n")
                        $script:luaPos++
                    }
                    'r' {
                        $null = $result.Append("`r")
                        $script:luaPos++
                    }
                    't' {
                        $null = $result.Append("`t")
                        $script:luaPos++
                    }
                    'v' {
                        $null = $result.Append([char]11)
                        $script:luaPos++
                    }
                    '\' {
                        $null = $result.Append('\')
                        $script:luaPos++
                    }
                    '"' {
                        $null = $result.Append('"')
                        $script:luaPos++
                    }
                    "'" {
                        $null = $result.Append("'")
                        $script:luaPos++
                    }
                    'x' {
                        # \xXX - two hex digits
                        $script:luaPos++
                        if ($script:luaPos + 1 -lt $script:luaString.Length) {
                            $hexStr = $script:luaString.Substring(
                                $script:luaPos, 2
                            )
                            if ($hexStr -notmatch '^[0-9a-fA-F]{2}$') {
                                throw 'Invalid \x escape sequence: expected two hexadecimal digits.'
                            }
                            $hexVal = [Convert]::ToInt32($hexStr, 16)
                            $null = $result.Append([char]$hexVal)
                            $script:luaPos += 2
                        } else {
                            throw 'Invalid \x escape sequence.'
                        }
                    }
                    'u' {
                        # \u{XXXX} - Unicode code point
                        $script:luaPos++
                        if ($script:luaPos -lt $script:luaString.Length -and
                            $script:luaString[$script:luaPos] -eq '{') {
                            $script:luaPos++
                            $hexStart = $script:luaPos
                            while ($script:luaPos -lt $script:luaString.Length -and
                                $script:luaString[$script:luaPos] -ne '}') {
                                $script:luaPos++
                            }
                            if ($script:luaPos -ge $script:luaString.Length) {
                                throw 'Invalid \u escape sequence: missing closing brace.'
                            }
                            $hexStr = $script:luaString.Substring(
                                $hexStart,
                                $script:luaPos - $hexStart
                            )
                            $codePoint = [Convert]::ToInt32($hexStr, 16)
                            $null = $result.Append(
                                [char]::ConvertFromUtf32($codePoint)
                            )
                            $script:luaPos++ # skip }
                        } else {
                            throw 'Invalid \u escape sequence.'
                        }
                    }
                    "`n" {
                        $null = $result.Append("`n")
                        $script:luaPos++
                        if (
                            $script:luaPos -lt $script:luaString.Length -and
                            $script:luaString[$script:luaPos] -eq "`r"
                        ) {
                            $script:luaPos++
                        }
                    }
                    "`r" {
                        $null = $result.Append("`n")
                        $script:luaPos++
                        if (
                            $script:luaPos -lt $script:luaString.Length -and
                            $script:luaString[$script:luaPos] -eq "`n"
                        ) {
                            $script:luaPos++
                        }
                    }
                    'z' {
                        $script:luaPos++
                        while (
                            $script:luaPos -lt $script:luaString.Length -and
                            [char]::IsWhiteSpace($script:luaString[$script:luaPos])
                        ) {
                            $script:luaPos++
                        }
                    }
                    default {
                        # \ddd - decimal byte sequence (1-3 digits)
                        if ($nextChar -match '[0-9]') {
                            $numStr = $nextChar.ToString()
                            $script:luaPos++
                            for ($d = 0; $d -lt 2; $d++) {
                                if ($script:luaPos -lt $script:luaString.Length -and
                                    $script:luaString[$script:luaPos] -match '[0-9]') {
                                    $numStr += $script:luaString[$script:luaPos]
                                    $script:luaPos++
                                } else {
                                    break
                                }
                            }
                            $null = $result.Append([char][int]$numStr)
                        } else {
                            # Unknown escape - just pass through
                            $null = $result.Append($nextChar)
                            $script:luaPos++
                        }
                    }
                }
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
