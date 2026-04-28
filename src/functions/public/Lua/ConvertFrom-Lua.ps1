function ConvertFrom-Lua {
    <#
        .SYNOPSIS
        Converts a Lua table constructor string to a PowerShell object.

        .DESCRIPTION
        Takes a Lua table constructor string and parses it into PowerShell objects.
        By default, Lua tables with string keys become PSCustomObjects and Lua
        sequences become arrays. Use -AsHashtable to get ordered hashtables instead.

        Supports the following Lua to PowerShell type mappings:
        - Lua table (key = value)                  -> [PSCustomObject] or [ordered] hashtable
        - Lua sequence (array)                     -> [object[]]
        - Lua double-quoted string                 -> [string]
        - Lua single-quoted string                 -> [string]
        - Lua multi-line string ([[ ]], [=[ ]=], [==[ ]==], etc.) -> [string]
        - Lua number (integer)                     -> [int] or [long]
        - Lua number (float)                       -> [double]
        - Lua boolean (true/false)                 -> [bool]
        - nil                                      -> $null
        - Single-line comments (--)                -> Ignored
        - Multi-line comments (--[[ ]], --[=[ ]=], --[==[ ]==], etc.) -> Ignored

        .EXAMPLE
        ```powershell
        '{ name = "Alice", age = 30 }' | ConvertFrom-Lua

        name  age
        ----  ---
        Alice  30
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
        '{ name = "Alice" }' | ConvertFrom-Lua -AsHashtable

        Name                           Value
        ----                           -----
        name                           Alice
        ```

        .NOTES
        [Lua 5.4 Reference Manual - Table Constructors](https://www.lua.org/manual/5.4/manual.html#3.4.9)

        .LINK
        https://psmodule.io/Lua/Functions/ConvertFrom-Lua/

        .LINK
        https://www.lua.org/manual/5.4/manual.html#3.4.9
    #>
    [OutputType([object])]
    [OutputType([System.Array])]
    [CmdletBinding()]
    param(
        # The Lua table constructor string to convert to a PowerShell object.
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $InputObject,

        # Output ordered hashtables instead of PSCustomObjects for Lua tables with string keys.
        [Parameter()]
        [switch] $AsHashtable,

        # Max nesting depth allowed in input. Throws a terminating error when exceeded.
        [Parameter()]
        [ValidateRange(0, 1024)]
        [int] $Depth = 1024,

        # Output arrays as a single object instead of enumerating elements through the pipeline.
        [Parameter()]
        [switch] $NoEnumerate,

        # Skip strict Lua grammar validation (e.g., reserved words as bare keys). Warnings are emitted instead of errors.
        [Parameter()]
        [switch] $SkipValidation
    )

    begin {}

    process {
        $convertParams = @{
            InputString      = $InputObject
            AsPSCustomObject = -not $AsHashtable
            MaxDepth         = $Depth
            SkipValidation   = $SkipValidation.IsPresent
        }
        $result = ConvertFrom-LuaTable @convertParams
        if ($NoEnumerate -and $result -is [System.Array]) {
            Write-Output -InputObject $result -NoEnumerate
        } else {
            $result
        }
    }

    end {}
}
