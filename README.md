# Lua

A PowerShell module for converting between PowerShell objects and Lua table notation.

## Prerequisites

This uses the following external resources:

- The [PSModule framework](https://github.com/PSModule/Process-PSModule) for building, testing and publishing the module.

## Installation

To install the module from the PowerShell Gallery, you can use the following command:

```powershell
Install-PSResource -Name Lua
Import-Module -Name Lua
```

## Usage

Here is a list of examples that are typical use cases for the module.

### Example 1: Convert a PowerShell hashtable to Lua

```powershell
@{ name = "ElvUI"; version = "13.74"; enabled = $true } | ConvertTo-Lua

{
    name = "ElvUI",
    version = "13.74",
    enabled = true
}
```

### Example 2: Convert a Lua table string to a PowerShell object

```powershell
$lua = '{ name = "ElvUI", version = "13.74", enabled = true }'
$config = $lua | ConvertFrom-Lua
$config.name     # ElvUI
$config.enabled  # True
```

### Example 3: Read a Lua file and convert to PowerShell

```powershell
$luaContent = Get-Content -Path 'config.lua' -Raw
$config = ConvertFrom-Lua -InputObject $luaContent
$config.unitframes.playerWidth  # 270
```

### Example 4: Convert a PowerShell object to compressed Lua

```powershell
@(1, 2, 3) | ConvertTo-Lua -Compress

{1,2,3}
```

### Example 5: Round-trip JSON to Lua

```powershell
$data = Get-Content -Path 'settings.json' -Raw | ConvertFrom-Json
$luaOutput = $data | ConvertTo-Lua
$luaOutput | Set-Content -Path 'settings.lua'
```

### Example 6: Convert Lua to PSCustomObject

```powershell
$result = '{ server = "localhost", port = 8080 }' | ConvertFrom-Lua
$result.server  # localhost
$result.port    # 8080
```

### Find more examples

To find more examples of how to use the module, please refer to the [examples](examples) folder.

Alternatively, you can use `Get-Command -Module 'Lua'` to find commands available in the module.
To find examples of each command, use `Get-Help -Examples 'CommandName'`.

## Documentation

For detailed documentation on each function, use the built-in help system:

```powershell
Get-Help ConvertTo-Lua -Full
Get-Help ConvertFrom-Lua -Full
```

## Contributing

Coder or not, you can contribute to the project! We welcome all contributions.

### For users

If you don't code, you still sit on valuable information that can make this project even better. If you experience that the
product does unexpected things, throw errors or is missing functionality, you can help by submitting bugs and feature requests.
Please see the issues tab on this project and submit a new issue that matches your needs.

### For developers

If you do code, we'd love to have your contributions. Please read the [Contribution guidelines](CONTRIBUTING.md) for more information.
You can either help by picking up an existing issue or submit a new one if you have an idea for a new feature or improvement.
