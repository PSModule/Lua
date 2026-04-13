function ConvertTo-Lua {
    <#
        .SYNOPSIS
        Converts a PowerShell object to a Lua table constructor string.

        .DESCRIPTION
        Takes a PowerShell object (hashtable, PSCustomObject, array, or primitive value) and
        converts it to a Lua table constructor string representation. Nested structures are
        recursively converted with 4-space indentation.

        Supports the following type mappings:
        - [hashtable] / [ordered] -> Lua table with key = value pairs
        - [PSCustomObject]        -> Lua table with key = value pairs
        - [array]                 -> Lua table (sequence)
        - [string]                -> Lua double-quoted string with escape sequences
        - [int] / [long]          -> Lua integer
        - [float] / [double]      -> Lua float
        - [bool]                  -> Lua boolean (true/false)
        - $null                   -> omitted (nil means absent in Lua)

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
        "hello" | ConvertTo-Lua -AsArray

        {
            "hello"
        }
        ```

        .NOTES
        [Lua 5.4 Reference Manual - Table Constructors](https://www.lua.org/manual/5.4/manual.html#3.4.9)

        .LINK
        https://psmodule.io/Lua/Functions/ConvertTo-Lua/

        .LINK
        https://www.lua.org/manual/5.4/manual.html#3.4.9
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        # The object to convert to a Lua table constructor string.
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowNull()]
        [object] $InputObject,

        # Max recursion depth for nested object serialization. Emits a warning when exceeded.
        [Parameter()]
        [ValidateRange(0, 100)]
        [int] $Depth = 2,

        # Omit whitespace and indentation.
        [Parameter()]
        [switch] $Compress,

        # Serialize PowerShell enum values as their string name instead of numeric value.
        [Parameter()]
        [switch] $EnumsAsStrings,

        # Always wrap output in a Lua sequence table, even for a single value.
        [Parameter()]
        [switch] $AsArray
    )

    begin {}

    process {
        $objectToConvert = $InputObject
        if ($AsArray -and $InputObject -isnot [System.Collections.IList]) {
            $objectToConvert = @(, $InputObject)
        }
        ConvertTo-LuaTable -InputObject $objectToConvert `
            -CurrentDepth 0 `
            -MaxDepth $Depth `
            -Compress:$Compress `
            -EnumsAsStrings:$EnumsAsStrings
    }

    end {}
}
