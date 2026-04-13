function ConvertTo-Lua {
    <#
        .SYNOPSIS
        Converts a PowerShell object to a Lua table string.

        .DESCRIPTION
        Takes a PowerShell object (hashtable, PSCustomObject, array, or primitive value) and
        converts it to a Lua table string representation. Nested structures are recursively
        converted with proper indentation.

        Supports the following type mappings:
        - [hashtable] / [ordered] -> Lua table with key = value pairs
        - [PSCustomObject]        -> Lua table with key = value pairs
        - [array]                 -> Lua table (sequence)
        - [string]                -> Lua double-quoted string with escape sequences
        - [int] / [long] / [double] / [decimal] -> Lua number
        - [bool]                  -> Lua boolean (true/false)
        - $null                   -> nil

        .EXAMPLE
        ```powershell
        @{ name = "Alice"; age = 30 } | ConvertTo-Lua

        {
            age = 30,
            name = "Alice"
        }
        ```

        .EXAMPLE
        ```powershell
        ConvertTo-Lua -InputObject @(1, 2, 3) -Compress

        {1,2,3}
        ```

        .EXAMPLE
        ```powershell
        [PSCustomObject]@{ server = "localhost"; port = 8080; enabled = $true } | ConvertTo-Lua

        {
            server = "localhost",
            port = 8080,
            enabled = true
        }
        ```

        .NOTES
        [Lua Table Documentation](https://www.lua.org/pil/2.5.html)

        .LINK
        https://psmodule.io/Lua/Functions/ConvertTo-Lua/

        .LINK
        https://www.lua.org/pil/2.5.html
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        # The object to convert to a Lua table string.
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowNull()]
        [object] $InputObject,

        # Number of spaces per indentation level.
        [Parameter()]
        [ValidateRange(1, 16)]
        [int] $Depth = 4,

        # Whether to compress the output by removing whitespace and newlines.
        [Parameter()]
        [switch] $Compress
    )

    begin {}

    process {
        ConvertTo-LuaTable -InputObject $InputObject -Depth 0 -IndentSize $Depth -Compress:$Compress
    }

    end {}
}
