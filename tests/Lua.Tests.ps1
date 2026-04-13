[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter', '',
    Justification = 'Required for Pester tests'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Required for Pester tests'
)]
[CmdletBinding()]
param()

Describe 'ConvertFrom-Lua' {
    BeforeAll {
        $dataPath = Join-Path -Path $PSScriptRoot -ChildPath 'data'
    }
    Context 'Primitives' {
        It 'Converts a Lua string to a PowerShell string' {
            $result = ConvertFrom-Lua -InputObject '"hello"'
            $result | Should -Be 'hello'
        }

        It 'Converts a Lua integer to a PowerShell int' {
            $result = ConvertFrom-Lua -InputObject '42'
            $result | Should -Be 42
            $result | Should -BeOfType [int]
        }

        It 'Converts a negative Lua integer' {
            $result = ConvertFrom-Lua -InputObject '-7'
            $result | Should -Be -7
        }

        It 'Converts a Lua float to a PowerShell double' {
            $result = ConvertFrom-Lua -InputObject '3.14'
            $result | Should -Be 3.14
            $result | Should -BeOfType [double]
        }

        It 'Converts Lua true to PowerShell $true' {
            $result = ConvertFrom-Lua -InputObject 'true'
            $result | Should -BeTrue
        }

        It 'Converts Lua false to PowerShell $false' {
            $result = ConvertFrom-Lua -InputObject 'false'
            $result | Should -BeFalse
        }

        It 'Converts Lua nil to PowerShell $null' {
            $result = ConvertFrom-Lua -InputObject 'nil'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Strings' {
        It 'Handles double-quoted strings' {
            $result = ConvertFrom-Lua -InputObject '"hello world"'
            $result | Should -Be 'hello world'
        }

        It 'Handles single-quoted strings' {
            $result = ConvertFrom-Lua -InputObject "'hello world'"
            $result | Should -Be 'hello world'
        }

        It 'Handles escape sequences in strings' {
            $result = ConvertFrom-Lua -InputObject '"line1\nline2"'
            $result | Should -Be "line1`nline2"
        }

        It 'Handles escaped quotes in strings' {
            $result = ConvertFrom-Lua -InputObject '"she said \"hi\""'
            $result | Should -Be 'she said "hi"'
        }

        It 'Handles escaped backslashes' {
            $result = ConvertFrom-Lua -InputObject '"path\\to\\file"'
            $result | Should -Be 'path\to\file'
        }

        It 'Handles multi-line strings with [[ ]]' {
            $result = ConvertFrom-Lua -InputObject '[[hello world]]'
            $result | Should -Be 'hello world'
        }
    }

    Context 'Arrays (sequences)' {
        It 'Converts a simple integer array' {
            $result = ConvertFrom-Lua -InputObject '{1, 2, 3}'
            $result.Count | Should -Be 3
            $result[0] | Should -Be 1
            $result[1] | Should -Be 2
            $result[2] | Should -Be 3
        }

        It 'Converts a string array' {
            $result = ConvertFrom-Lua -InputObject '{"a", "b", "c"}'
            $result.Count | Should -Be 3
            $result[0] | Should -Be 'a'
            $result[1] | Should -Be 'b'
            $result[2] | Should -Be 'c'
        }

        It 'Converts an empty table to an empty hashtable' {
            $result = ConvertFrom-Lua -InputObject '{}'
            $result.Count | Should -Be 0
        }

        It 'Converts nested arrays' {
            $result = ConvertFrom-Lua -InputObject '{{1, 2}, {3, 4}}'
            $result.Count | Should -Be 2
            $result[0].Count | Should -Be 2
            $result[0][0] | Should -Be 1
            $result[1][1] | Should -Be 4
        }
    }

    Context 'Tables (dictionaries)' {
        It 'Converts a simple key-value table' {
            $result = ConvertFrom-Lua -InputObject '{ name = "Alice", age = 30 }'
            $result.name | Should -Be 'Alice'
            $result.age | Should -Be 30
        }

        It 'Converts bracket-quoted keys' {
            $result = ConvertFrom-Lua -InputObject '{ ["special key"] = "value" }'
            $result['special key'] | Should -Be 'value'
        }

        It 'Converts nested tables' {
            $result = ConvertFrom-Lua -InputObject '{ inner = { x = 1, y = 2 } }'
            $result.inner.x | Should -Be 1
            $result.inner.y | Should -Be 2
        }

        It 'Handles boolean values in tables' {
            $result = ConvertFrom-Lua -InputObject '{ enabled = true, debug = false }'
            $result.enabled | Should -BeTrue
            $result.debug | Should -BeFalse
        }

        It 'Returns PSCustomObject when -AsObject is used' {
            $result = ConvertFrom-Lua -InputObject '{ name = "Alice" }' -AsObject
            $result | Should -BeOfType [PSCustomObject]
            $result.name | Should -Be 'Alice'
        }
    }

    Context 'Comments' {
        It 'Ignores single-line comments' {
            $lua = @'
{
    -- This is a comment
    name = "Alice",
    age = 30 -- inline comment
}
'@
            $result = ConvertFrom-Lua -InputObject $lua
            $result.name | Should -Be 'Alice'
            $result.age | Should -Be 30
        }

        It 'Ignores multi-line comments' {
            $lua = @'
{
    --[[ This is a
         multi-line comment ]]
    name = "Bob"
}
'@
            $result = ConvertFrom-Lua -InputObject $lua
            $result.name | Should -Be 'Bob'
        }
    }

    Context 'Pipeline input' {
        It 'Accepts input from the pipeline' {
            $result = '{ x = 10 }' | ConvertFrom-Lua
            $result.x | Should -Be 10
        }
    }

    Context 'File-based test: Strings' {
        BeforeAll {
            $luaContent = Get-Content -Path (Join-Path $dataPath 'Strings.lua') -Raw
            $expected = Get-Content -Path (Join-Path $dataPath 'Strings.json') -Raw | ConvertFrom-Json
        }

        It 'Parses string test file and matches JSON reference' {
            $result = ConvertFrom-Lua -InputObject $luaContent
            $result.simpleString | Should -Be $expected.simpleString
            $result.escapedQuote | Should -Be $expected.escapedQuote
            $result.newlineString | Should -Be $expected.newlineString
            $result.tabString | Should -Be $expected.tabString
            $result.backslash | Should -Be $expected.backslash
        }
    }

    Context 'File-based test: Arrays' {
        BeforeAll {
            $luaContent = Get-Content -Path (Join-Path $dataPath 'Arrays.lua') -Raw
            $expected = Get-Content -Path (Join-Path $dataPath 'Arrays.json') -Raw | ConvertFrom-Json
        }

        It 'Parses integer arrays correctly' {
            $result = ConvertFrom-Lua -InputObject $luaContent
            $result.integers.Count | Should -Be $expected.integers.Count
            for ($i = 0; $i -lt $expected.integers.Count; $i++) {
                $result.integers[$i] | Should -Be $expected.integers[$i]
            }
        }

        It 'Parses float arrays correctly' {
            $result = ConvertFrom-Lua -InputObject $luaContent
            $result.floats.Count | Should -Be $expected.floats.Count
            for ($i = 0; $i -lt $expected.floats.Count; $i++) {
                $result.floats[$i] | Should -Be $expected.floats[$i]
            }
        }

        It 'Parses boolean arrays correctly' {
            $result = ConvertFrom-Lua -InputObject $luaContent
            $result.booleans[0] | Should -BeTrue
            $result.booleans[1] | Should -BeFalse
        }
    }

    Context 'File-based test: TestStructure' {
        BeforeAll {
            $luaContent = Get-Content -Path (Join-Path $dataPath 'TestStructure.lua') -Raw
            $expected = Get-Content -Path (Join-Path $dataPath 'TestStructure.json') -Raw | ConvertFrom-Json
        }

        It 'Parses top-level string properties' {
            $result = ConvertFrom-Lua -InputObject $luaContent
            $result.name | Should -Be $expected.name
            $result.version | Should -Be $expected.version
            $result.description | Should -Be $expected.description
        }

        It 'Parses top-level boolean properties' {
            $result = ConvertFrom-Lua -InputObject $luaContent
            $result.enabled | Should -Be $expected.enabled
            $result.debug | Should -Be $expected.debug
        }

        It 'Parses top-level numeric properties' {
            $result = ConvertFrom-Lua -InputObject $luaContent
            $result.maxRetries | Should -Be $expected.maxRetries
            $result.scaling | Should -Be $expected.scaling
        }

        It 'Parses array properties' {
            $result = ConvertFrom-Lua -InputObject $luaContent
            $result.authors.Count | Should -Be $expected.authors.Count
            $result.authors[0] | Should -Be $expected.authors[0]
            $result.authors[1] | Should -Be $expected.authors[1]
            $result.authors[2] | Should -Be $expected.authors[2]
        }

        It 'Parses nested table properties' {
            $result = ConvertFrom-Lua -InputObject $luaContent
            $result.unitframes.enabled | Should -Be $expected.unitframes.enabled
            $result.unitframes.playerWidth | Should -Be $expected.unitframes.playerWidth
            $result.unitframes.playerHeight | Should -Be $expected.unitframes.playerHeight
        }

        It 'Parses deeply nested structures' {
            $result = ConvertFrom-Lua -InputObject $luaContent
            $result.unitframes.colors.health.Count | Should -Be 3
            $result.unitframes.colors.health[0] | Should -Be $expected.unitframes.colors.health[0]
        }

        It 'Parses the chat section' {
            $result = ConvertFrom-Lua -InputObject $luaContent
            $result.chat.fontSize | Should -Be $expected.chat.fontSize
            $result.chat.panelWidth | Should -Be $expected.chat.panelWidth
            $result.chat.fadeChat | Should -Be $expected.chat.fadeChat
            $result.chat.keywords | Should -Be $expected.chat.keywords
        }

        It 'Parses actionbar nested tables' {
            $result = ConvertFrom-Lua -InputObject $luaContent
            $result.actionbars.bar1.enabled | Should -Be $expected.actionbars.bar1.enabled
            $result.actionbars.bar1.buttons | Should -Be $expected.actionbars.bar1.buttons
            $result.actionbars.bar2.buttonSize | Should -Be $expected.actionbars.bar2.buttonSize
        }

        It 'Parses bracket-quoted keys' {
            $result = ConvertFrom-Lua -InputObject $luaContent
            $result['specialKey'] | Should -Be $expected.specialKey
        }

        It 'Parses unicode strings' {
            $result = ConvertFrom-Lua -InputObject $luaContent
            $result.unicodeNote | Should -Be $expected.unicodeNote
        }
    }
}

Describe 'ConvertTo-Lua' {
    BeforeAll {
        $dataPath = Join-Path -Path $PSScriptRoot -ChildPath 'data'
    }

    Context 'Primitives' {
        It 'Converts a string to Lua string' {
            $result = ConvertTo-Lua -InputObject 'hello'
            $result | Should -Be '"hello"'
        }

        It 'Converts an integer to Lua number' {
            $result = ConvertTo-Lua -InputObject 42
            $result | Should -Be '42'
        }

        It 'Converts a negative integer' {
            $result = ConvertTo-Lua -InputObject (-7)
            $result | Should -Be '-7'
        }

        It 'Converts a double to Lua number' {
            $result = ConvertTo-Lua -InputObject 3.14
            $result | Should -Be '3.14'
        }

        It 'Converts $true to Lua true' {
            $result = ConvertTo-Lua -InputObject $true
            $result | Should -Be 'true'
        }

        It 'Converts $false to Lua false' {
            $result = ConvertTo-Lua -InputObject $false
            $result | Should -Be 'false'
        }

        It 'Converts $null to Lua nil' {
            $result = ConvertTo-Lua -InputObject $null
            $result | Should -Be 'nil'
        }
    }

    Context 'String escaping' {
        It 'Escapes double quotes in strings' {
            $result = ConvertTo-Lua -InputObject 'she said "hi"'
            $result | Should -Be '"she said \"hi\""'
        }

        It 'Escapes backslashes in strings' {
            $result = ConvertTo-Lua -InputObject 'path\to\file'
            $result | Should -Be '"path\\to\\file"'
        }

        It 'Escapes newlines in strings' {
            $result = ConvertTo-Lua -InputObject "line1`nline2"
            $result | Should -Be '"line1\nline2"'
        }

        It 'Escapes tabs in strings' {
            $result = ConvertTo-Lua -InputObject "col1`tcol2"
            $result | Should -Be '"col1\tcol2"'
        }
    }

    Context 'Arrays' {
        It 'Converts a simple array (compressed)' {
            $result = ConvertTo-Lua -InputObject @(1, 2, 3) -Compress
            $result | Should -Be '{1,2,3}'
        }

        It 'Converts an empty array' {
            $result = ConvertTo-Lua -InputObject @() -Compress
            $result | Should -Be '{}'
        }

        It 'Converts a string array (compressed)' {
            $result = ConvertTo-Lua -InputObject @('a', 'b') -Compress
            $result | Should -Be '{"a","b"}'
        }

        It 'Converts an array with indentation' {
            $result = ConvertTo-Lua -InputObject @(1, 2)
            $result | Should -Match '^\{'
            $result | Should -Match '1'
            $result | Should -Match '2'
            $result | Should -Match '\}$'
        }
    }

    Context 'Hashtables' {
        It 'Converts a simple hashtable (compressed)' {
            $result = ConvertTo-Lua -InputObject @{ x = 1 } -Compress
            $result | Should -Be '{x=1}'
        }

        It 'Converts an empty hashtable' {
            $result = ConvertTo-Lua -InputObject @{} -Compress
            $result | Should -Be '{}'
        }

        It 'Converts nested hashtables (compressed)' {
            $result = ConvertTo-Lua -InputObject ([ordered]@{ inner = ([ordered]@{ a = 1 }) }) -Compress
            $result | Should -Be '{inner={a=1}}'
        }

        It 'Handles keys with special characters' {
            $result = ConvertTo-Lua -InputObject @{ 'my key' = 'value' } -Compress
            $result | Should -Be '{["my key"]="value"}'
        }
    }

    Context 'PSCustomObject' {
        It 'Converts a PSCustomObject (compressed)' {
            $obj = [PSCustomObject]@{ name = 'test'; value = 42 }
            $result = ConvertTo-Lua -InputObject $obj -Compress
            $result | Should -Match 'name="test"'
            $result | Should -Match 'value=42'
        }
    }

    Context 'Pipeline input' {
        It 'Accepts input from the pipeline' {
            $result = @{ x = 10 } | ConvertTo-Lua -Compress
            $result | Should -Be '{x=10}'
        }
    }

    Context 'Round-trip conversion' {
        It 'Round-trips a simple hashtable' {
            $original = [ordered]@{ name = 'test'; count = 5; active = $true }
            $lua = ConvertTo-Lua -InputObject $original
            $result = ConvertFrom-Lua -InputObject $lua
            $result.name | Should -Be $original.name
            $result.count | Should -Be $original.count
            $result.active | Should -Be $original.active
        }

        It 'Round-trips an array' {
            $original = @(1, 2, 3, 4, 5)
            $lua = ConvertTo-Lua -InputObject $original
            $result = ConvertFrom-Lua -InputObject $lua
            $result.Count | Should -Be 5
            for ($i = 0; $i -lt 5; $i++) {
                $result[$i] | Should -Be $original[$i]
            }
        }

        It 'Round-trips nested structures' {
            $original = [ordered]@{
                server  = 'localhost'
                port    = 8080
                options = [ordered]@{
                    debug   = $false
                    verbose = $true
                }
            }
            $lua = ConvertTo-Lua -InputObject $original
            $result = ConvertFrom-Lua -InputObject $lua
            $result.server | Should -Be 'localhost'
            $result.port | Should -Be 8080
            $result.options.debug | Should -BeFalse
            $result.options.verbose | Should -BeTrue
        }

        It 'Round-trips from JSON reference to Lua and back' {
            $jsonPath = Join-Path $dataPath 'TestStructure.json'
            $expected = Get-Content -Path $jsonPath -Raw | ConvertFrom-Json
            $lua = ConvertTo-Lua -InputObject $expected
            $result = ConvertFrom-Lua -InputObject $lua
            $result.name | Should -Be $expected.name
            $result.enabled | Should -Be $expected.enabled
            $result.maxRetries | Should -Be $expected.maxRetries
            $result.authors.Count | Should -Be $expected.authors.Count
        }
    }

    Context 'Indentation' {
        It 'Uses custom indent size' {
            $result = ConvertTo-Lua -InputObject @(1) -Depth 2
            $lines = $result -split "`n"
            $lines[1] | Should -Match '^  1$'
        }

        It 'Compress removes all whitespace and newlines' {
            $result = ConvertTo-Lua -InputObject ([ordered]@{ a = 1; b = 2 }) -Compress
            $result | Should -Not -Match "`n"
            $result | Should -Not -Match '  '
        }
    }
}
