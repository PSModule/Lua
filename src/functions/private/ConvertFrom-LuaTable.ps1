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
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
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
                $script:luaString[$nextPos] -notmatch '[a-zA-Z0-9_]') {
                $script:luaPos = $nextPos
                Skip-LuaWhitespace
            }
        }

        # Detect assignment statements: Name = value (common in Lua data/config files)
        # A chunk in Lua is a block of statements; assignment is: varlist '=' explist
        # We support one or more simple assignments: Name = value
        $assignmentDetected = $false
        $savedPos = $script:luaPos
        if ($script:luaPos -lt $script:luaString.Length -and
            $script:luaString[$script:luaPos] -match '[a-zA-Z_]') {
            # Try to read an identifier
            $tryPos = $script:luaPos
            while ($tryPos -lt $script:luaString.Length -and
                $script:luaString[$tryPos] -match '[a-zA-Z0-9_]') {
                $tryPos++
            }
            $tryIdent = $script:luaString.Substring($script:luaPos, $tryPos - $script:luaPos)
            # Check it's not a keyword that starts a value (true/false/nil)
            if ($tryIdent -notin 'true', 'false', 'nil') {
                # Skip whitespace after identifier to check for '='
                $peekPos = $tryPos
                while ($peekPos -lt $script:luaString.Length -and
                    $script:luaString[$peekPos] -match '\s') {
                    $peekPos++
                }
                # Check for '=' but not '=='
                if ($peekPos -lt $script:luaString.Length -and
                    $script:luaString[$peekPos] -eq '=' -and
                    ($peekPos + 1 -ge $script:luaString.Length -or
                    $script:luaString[$peekPos + 1] -ne '=')) {
                    $assignmentDetected = $true
                }
            }
        }

        if ($assignmentDetected) {
            # Parse one or more assignment statements into an ordered dictionary
            $assignments = [ordered]@{}
            while ($script:luaPos -lt $script:luaString.Length) {
                Skip-LuaWhitespace
                if ($script:luaPos -ge $script:luaString.Length) {
                    break
                }

                # Read variable name
                $identStart = $script:luaPos
                if ($script:luaString[$script:luaPos] -notmatch '[a-zA-Z_]') {
                    throw "Expected variable name at position $($script:luaPos)."
                }
                while ($script:luaPos -lt $script:luaString.Length -and
                    $script:luaString[$script:luaPos] -match '[a-zA-Z0-9_]') {
                    $script:luaPos++
                }
                $varName = $script:luaString.Substring($identStart, $script:luaPos - $identStart)

                Skip-LuaWhitespace

                # Expect '='
                if ($script:luaPos -ge $script:luaString.Length -or
                    $script:luaString[$script:luaPos] -ne '=') {
                    throw "Expected '=' after variable name '$varName' at position $($script:luaPos)."
                }
                $script:luaPos++ # skip '='

                # Read value
                $value = Read-LuaValue
                $assignments[$varName] = $value

                Skip-LuaWhitespace
            }

            if ($script:luaAsPSCustomObject) {
                return [PSCustomObject]$assignments
            }
            return $assignments
        }

        # Reset position (no assignment detected, or it was a keyword value)
        $script:luaPos = $savedPos

        $result = Read-LuaValue

        Skip-LuaWhitespace
        if ($script:luaPos -lt $script:luaString.Length) {
            $remainingInput = $script:luaString.Substring($script:luaPos)
            throw "Unexpected trailing content after Lua value at position $($script:luaPos): $remainingInput"
        }

        return $result
    }

    end {}
}
