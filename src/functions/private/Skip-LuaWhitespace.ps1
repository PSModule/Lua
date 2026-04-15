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

                # Multi-line comment --[[ ... ]] or --[=[ ... ]=] etc.
                if ($script:luaPos -lt $script:luaString.Length -and
                    $script:luaString[$script:luaPos] -eq '[') {
                    $eqStart = $script:luaPos + 1
                    $eqCount = 0
                    while ($eqStart + $eqCount -lt $script:luaString.Length -and
                        $script:luaString[$eqStart + $eqCount] -eq '=') {
                        $eqCount++
                    }
                    if ($eqStart + $eqCount -lt $script:luaString.Length -and
                        $script:luaString[$eqStart + $eqCount] -eq '[') {
                        # Valid long bracket comment opening
                        $script:luaPos = $eqStart + $eqCount + 1
                        $closePattern = ']' + ('=' * $eqCount) + ']'
                        $closeLen = $closePattern.Length
                        $foundClosingDelimiter = $false
                        while ($script:luaPos -lt $script:luaString.Length) {
                            if ($script:luaPos + $closeLen - 1 -lt $script:luaString.Length -and
                                $script:luaString.Substring($script:luaPos, $closeLen) -eq $closePattern) {
                                $script:luaPos += $closeLen
                                $foundClosingDelimiter = $true
                                break
                            }
                            $script:luaPos++
                        }
                        if (-not $foundClosingDelimiter) {
                            throw "Unterminated long-bracket comment."
                        }
                    } else {
                        # Not a long bracket - treat as single-line comment
                        while ($script:luaPos -lt $script:luaString.Length -and
                            $script:luaString[$script:luaPos] -ne "`n") {
                            $script:luaPos++
                        }
                    }
                } else {
                    # Single-line comment
                    while ($script:luaPos -lt $script:luaString.Length -and
                        $script:luaString[$script:luaPos] -ne "`n") {
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
