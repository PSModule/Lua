function ConvertFrom-LuaTable {
    <#
        .SYNOPSIS
        Parses a Lua table constructor string into a PowerShell object.

        .DESCRIPTION
        Takes a Lua table constructor string and converts it to PowerShell
        hashtables, arrays, and primitive types. This is the internal parsing
        engine used by ConvertFrom-Lua.
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

        # Skip optional leading 'return' keyword (common in Lua data files)
        if ($script:luaPos + 6 -le $script:luaString.Length -and
            $script:luaString.Substring($script:luaPos, 6) -ceq 'return') {
            $nextPos = $script:luaPos + 6
            if ($nextPos -ge $script:luaString.Length -or
                $script:luaString[$nextPos] -match '[\s{]') {
                $script:luaPos = $nextPos
                Skip-LuaWhitespace
            }
        }

        $result = Read-LuaValue

        return $result
    }

    end {}
}
