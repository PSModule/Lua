function ConvertFrom-Lua {
    <#
        .SYNOPSIS
        Converts a Lua table string to a PowerShell object.

        .DESCRIPTION
        Takes a Lua table string and parses it into PowerShell objects. Lua tables with
        string keys become ordered hashtables (or PSCustomObjects with -AsObject), Lua
        sequences become arrays, and Lua primitives are converted to their PowerShell
        equivalents.

        Supports the following Lua to PowerShell type mappings:
        - Lua table (key = value)     -> [ordered] hashtable or [PSCustomObject]
        - Lua sequence (array)        -> [object[]]
        - Lua double-quoted string    -> [string]
        - Lua single-quoted string    -> [string]
        - Lua multi-line string [[ ]] -> [string]
        - Lua number (integer)        -> [int] or [long]
        - Lua number (float)          -> [double]
        - Lua boolean (true/false)    -> [bool]
        - nil                         -> $null
        - Single-line comments (--)   -> Ignored
        - Multi-line comments (--[[ ]]) -> Ignored

        .EXAMPLE
        ```powershell
        '{ name = "Alice", age = 30 }' | ConvertFrom-Lua

        Name                           Value
        ----                           -----
        name                           Alice
        age                            30
        ```

        .EXAMPLE
        ```powershell
        ConvertFrom-Lua -InputObject '{ 1, 2, 3 }'

        1
        2
        3
        ```

        .EXAMPLE
        ```powershell
        '{ server = "localhost", port = 8080, enabled = true }' | ConvertFrom-Lua -AsObject

        server    port enabled
        ------    ---- -------
        localhost 8080    True
        ```

        .NOTES
        [Lua Table Documentation](https://www.lua.org/pil/2.5.html)

        .LINK
        https://psmodule.io/Lua/Functions/ConvertFrom-Lua/

        .LINK
        https://www.lua.org/pil/2.5.html
    #>
    [OutputType([object])]
    [CmdletBinding()]
    param(
        # The Lua table string to convert to a PowerShell object.
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $InputObject,

        # Output PSCustomObjects instead of hashtables for Lua tables with string keys.
        [Parameter()]
        [switch] $AsObject
    )

    begin {}

    process {
        ConvertFrom-LuaTable -InputString $InputObject -AsPSCustomObject:$AsObject
    }

    end {}
}
