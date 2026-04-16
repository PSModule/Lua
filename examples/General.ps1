<#
    .SYNOPSIS
    Examples of how to use the Lua module.
#>

# Import the module
Import-Module -Name 'Lua'

# Convert a PowerShell hashtable to Lua table notation
$config = [ordered]@{
    name    = 'ElvUI'
    version = '13.74'
    enabled = $true
    scaling = 0.85
    authors = @('Elv', 'Simpy', 'Blazeflack')
}
$luaOutput = $config | ConvertTo-Lua
Write-Output $luaOutput

# Convert a Lua table string to a PowerShell object
$luaString = @'
{
    name = "ElvUI",
    version = "13.74",
    enabled = true,
    unitframes = {
        playerWidth = 270,
        playerHeight = 54
    }
}
'@
$result = $luaString | ConvertFrom-Lua
Write-Output "Name: $($result.name)"
Write-Output "Player Width: $($result.unitframes.playerWidth)"

# Convert Lua to PSCustomObject
$obj = '{ server = "localhost", port = 8080 }' | ConvertFrom-Lua
Write-Output "Server: $($obj.server), Port: $($obj.port)"

# Compressed output
$compressed = @(1, 2, 3, 4, 5) | ConvertTo-Lua -Compress
Write-Output "Compressed: $compressed"

