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
