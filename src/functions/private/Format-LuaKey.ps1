function Format-LuaKey {
    <#
        .SYNOPSIS
        Formats a string as a valid Lua table key.

        .DESCRIPTION
        Returns the key as a bare identifier if it matches Lua identifier rules,
        otherwise wraps it in bracket-quote notation: ["key"].
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        # The key string to format.
        [Parameter(Mandatory)]
        [string] $Key
    )

    begin {}

    process {
        if ($Key -match '^[a-zA-Z_][a-zA-Z0-9_]*$') {
            return $Key
        }
        $escaped = $Key -replace '\\', '\\\\' -replace '"', '\"'
        return "[`"$escaped`"]"
    }

    end {}
}
