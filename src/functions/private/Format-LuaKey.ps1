function Format-LuaKey {
    <#
        .SYNOPSIS
        Formats a string as a valid Lua table key.

        .DESCRIPTION
        Returns the key as a bare identifier if it matches Lua identifier rules
        and is not a reserved word, otherwise wraps it in bracket-quote notation: ["key"].
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        # The key string to format.
        [Parameter(Mandatory)]
        [string] $Key
    )

    begin {
        # Lua 5.4 reserved words per §3.1
        $reservedWords = @(
            'and', 'break', 'do', 'else', 'elseif', 'end',
            'false', 'for', 'function', 'goto', 'if', 'in',
            'local', 'nil', 'not', 'or', 'repeat', 'return',
            'then', 'true', 'until', 'while'
        )
    }

    process {
        if ($Key -match '^[a-zA-Z_][a-zA-Z0-9_]*$' -and $Key -notin $reservedWords) {
            return $Key
        }
        $escaped = $Key `
            -replace '\\', '\\' `
            -replace '"', '\"' `
            -replace "`0", '\0' `
            -replace "`a", '\a' `
            -replace "`n", '\n' `
            -replace "`r", '\r' `
            -replace "`t", '\t' `
            -replace "`v", '\v' `
            -replace "`b", '\b' `
            -replace "`f", '\f'
        return "[`"$escaped`"]"
    }

    end {}
}
