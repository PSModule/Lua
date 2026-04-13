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

        It 'Converts a large integer to long' {
            $result = ConvertFrom-Lua -InputObject '3000000000'
            $result | Should -Be 3000000000
            $result | Should -BeOfType [long]
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

        It 'Handles escape sequences: \n \r \t' {
            $result = ConvertFrom-Lua -InputObject '"line1\nline2"'
            $result | Should -Be "line1`nline2"
        }

        It 'Handles \r escape' {
            $result = ConvertFrom-Lua -InputObject '"a\rb"'
            $result | Should -Be "a`rb"
        }

        It 'Handles \t escape' {
            $result = ConvertFrom-Lua -InputObject '"col1\tcol2"'
            $result | Should -Be "col1`tcol2"
        }

        It 'Handles escaped quotes in strings' {
            $result = ConvertFrom-Lua -InputObject '"she said \"hi\""'
            $result | Should -Be 'she said "hi"'
        }

        It 'Handles escaped backslashes' {
            $result = ConvertFrom-Lua -InputObject '"path\\to\\file"'
            $result | Should -Be 'path\to\file'
        }

        It 'Handles \a (bell) escape' {
            $result = ConvertFrom-Lua -InputObject '"test\abell"'
            $result | Should -Be "test$([char]7)bell"
        }

        It 'Handles \b (backspace) escape' {
            $result = ConvertFrom-Lua -InputObject '"test\bback"'
            $result | Should -Be "test`bback"
        }

        It 'Handles \f (form feed) escape' {
            $result = ConvertFrom-Lua -InputObject '"test\ffeed"'
            $result | Should -Be "test$([char]12)feed"
        }

        It 'Handles \v (vertical tab) escape' {
            $result = ConvertFrom-Lua -InputObject '"test\vtab"'
            $result | Should -Be "test$([char]11)tab"
        }

        It 'Handles \xXX hex escape' {
            $result = ConvertFrom-Lua -InputObject '"test\x41char"'
            $result | Should -Be 'testAchar'
        }

        It 'Handles \ddd decimal escape' {
            $result = ConvertFrom-Lua -InputObject '"test\065char"'
            $result | Should -Be 'testAchar'
        }

        It 'Handles \u{XXXX} unicode escape' {
            $result = ConvertFrom-Lua -InputObject '"test\u{0041}char"'
            $result | Should -Be 'testAchar'
        }

        It 'Handles multi-line strings with [[ ]]' {
            $result = ConvertFrom-Lua -InputObject '[[hello world]]'
            $result | Should -Be 'hello world'
        }

        It 'Multi-line string strips leading newline' {
            $lua = "[[$([System.Environment]::NewLine)hello]]"
            $result = ConvertFrom-Lua -InputObject $lua
            $result | Should -Be 'hello'
        }

        It 'Handles escaped single quote in single-quoted string' {
            # Lua uses \' inside single-quoted strings
            $result = ConvertFrom-Lua -InputObject "'it\'s'"
            $result | Should -Be "it's"
        }
    }

    Context 'Numbers' {
        It 'Parses hex integer 0xFF' {
            $result = ConvertFrom-Lua -InputObject '0xFF'
            $result | Should -Be 255
            $result | Should -BeOfType [int]
        }

        It 'Parses hex integer 0x1A' {
            $result = ConvertFrom-Lua -InputObject '0x1A'
            $result | Should -Be 26
        }

        It 'Parses scientific notation 1e10' {
            $result = ConvertFrom-Lua -InputObject '1e10'
            $result | Should -Be 10000000000.0
            $result | Should -BeOfType [double]
        }

        It 'Parses scientific notation with negative exponent 1.5e-3' {
            $result = ConvertFrom-Lua -InputObject '1.5e-3'
            $result | Should -Be 0.0015
        }

        It 'Parses hex float 0x1.fp10' {
            $result = ConvertFrom-Lua -InputObject '0x1.fp10'
            # 0x1.f = 1 + 15/16 = 1.9375, * 2^10 = 1984
            $result | Should -Be 1984.0
        }

        It 'Parses negative hex -0xFF' {
            $result = ConvertFrom-Lua -InputObject '-0xFF'
            $result | Should -Be -255
        }

        It 'Parses zero' {
            $result = ConvertFrom-Lua -InputObject '0'
            $result | Should -Be 0
            $result | Should -BeOfType [int]
        }

        It 'Parses negative float' {
            $result = ConvertFrom-Lua -InputObject '-2.5'
            $result | Should -Be -2.5
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

        It 'Converts an empty table' {
            $result = ConvertFrom-Lua -InputObject '{}'
            if ($result -is [System.Collections.IDictionary]) {
                $result.Count | Should -Be 0
            } else {
                @($result.PSObject.Properties).Count | Should -Be 0
            }
        }

        It 'Converts nested arrays' {
            $result = ConvertFrom-Lua -InputObject '{{1, 2}, {3, 4}}'
            $result.Count | Should -Be 2
            $result[0].Count | Should -Be 2
            $result[0][0] | Should -Be 1
            $result[1][1] | Should -Be 4
        }

        It 'Converts deeply nested arrays (3 levels)' {
            $result = ConvertFrom-Lua -InputObject '{{{1, 2}, {3, 4}}, {{5, 6}}}'
            $result.Count | Should -Be 2
            $result[0].Count | Should -Be 2
            $result[0][0].Count | Should -Be 2
            $result[0][0][0] | Should -Be 1
            $result[0][1][1] | Should -Be 4
            $result[1][0][0] | Should -Be 5
        }

        It 'Handles semicolons as separators' {
            $result = ConvertFrom-Lua -InputObject '{1; 2; 3}'
            $result.Count | Should -Be 3
            $result[0] | Should -Be 1
            $result[2] | Should -Be 3
        }

        It 'Handles trailing separator' {
            $result = ConvertFrom-Lua -InputObject '{1, 2, 3,}'
            $result.Count | Should -Be 3
        }

        It 'Handles mixed separators (comma and semicolon)' {
            $result = ConvertFrom-Lua -InputObject '{1, 2; 3}'
            $result.Count | Should -Be 3
        }
    }

    Context 'Tables (dictionaries) - default PSCustomObject output' {
        It 'Converts a simple key-value table to PSCustomObject' {
            $result = ConvertFrom-Lua -InputObject '{ name = "Alice", age = 30 }'
            $result | Should -BeOfType [PSCustomObject]
            $result.name | Should -Be 'Alice'
            $result.age | Should -Be 30
        }

        It 'Converts bracket-quoted keys' {
            $result = ConvertFrom-Lua -InputObject '{ ["special key"] = "value" }'
            $result.'special key' | Should -Be 'value'
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
    }

    Context 'Tables - AsHashtable output' {
        It 'Returns ordered hashtable when -AsHashtable is used' {
            $result = ConvertFrom-Lua -InputObject '{ name = "Alice" }' -AsHashtable
            $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
            $result.name | Should -Be 'Alice'
        }

        It 'AsHashtable preserves key order' {
            $result = ConvertFrom-Lua -InputObject '{ a = 1, b = 2, c = 3 }' -AsHashtable
            $keys = @($result.Keys)
            $keys[0] | Should -Be 'a'
            $keys[1] | Should -Be 'b'
            $keys[2] | Should -Be 'c'
        }
    }

    Context 'Mixed tables' {
        It 'Handles mixed tables with sequential and named keys' {
            $result = ConvertFrom-Lua -InputObject '{ "a", name = "x" }'
            $result.'1' | Should -Be 'a'
            $result.name | Should -Be 'x'
        }

        It 'Mixed table sequential keys start at 1' {
            $result = ConvertFrom-Lua -InputObject '{ "first", "second", key = "val" }' -AsHashtable
            $result['1'] | Should -Be 'first'
            $result['2'] | Should -Be 'second'
            $result['key'] | Should -Be 'val'
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

        It 'Handles comment before closing brace' {
            $lua = @'
{
    x = 1
    -- trailing comment
}
'@
            $result = ConvertFrom-Lua -InputObject $lua
            $result.x | Should -Be 1
        }
    }

    Context 'Depth limiting' {
        It 'Throws when nesting exceeds -Depth' {
            $lua = '{ a = { b = { c = 1 } } }'
            { ConvertFrom-Lua -InputObject $lua -Depth 2 } | Should -Throw '*depth*'
        }

        It 'Allows nesting within -Depth limit' {
            $lua = '{ a = { b = 1 } }'
            $result = ConvertFrom-Lua -InputObject $lua -Depth 5
            $result.a.b | Should -Be 1
        }
    }

    Context 'NoEnumerate' {
        It 'Without -NoEnumerate, arrays are enumerated' {
            $result = @(ConvertFrom-Lua -InputObject '{1, 2, 3}')
            $result.Count | Should -Be 3
        }

        It 'With -NoEnumerate, arrays are returned as single object' {
            $result = ConvertFrom-Lua -InputObject '{1, 2, 3}' -NoEnumerate
            , $result | Should -HaveCount 1
            $result.Count | Should -Be 3
        }
    }

    Context 'Error cases' {
        It 'Throws on bare identifier (variable reference)' {
            { ConvertFrom-Lua -InputObject 'someVariable' } | Should -Throw '*bare identifier*'
        }

        It 'Throws on bare identifier inside table' {
            { ConvertFrom-Lua -InputObject '{ myVar }' } | Should -Throw '*bare identifier*'
        }

        It 'Throws on unterminated string' {
            { ConvertFrom-Lua -InputObject '"hello' } | Should -Throw '*Unterminated*'
        }

        It 'Throws on unterminated multi-line string' {
            { ConvertFrom-Lua -InputObject '[[hello' } | Should -Throw '*Unterminated*'
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
            $result.specialKey | Should -Be $expected.specialKey
        }

        It 'Parses unicode strings' {
            $result = ConvertFrom-Lua -InputObject $luaContent
            $result.unicodeNote | Should -Be $expected.unicodeNote
        }
    }

    Context 'File-based test: DeepStructure' {
        BeforeAll {
            $luaContent = Get-Content -Path (Join-Path $dataPath 'DeepStructure.lua') -Raw
            $expected = Get-Content -Path (Join-Path $dataPath 'DeepStructure.json') -Raw | ConvertFrom-Json
        }

        It 'Parses 5-level deep nested value' {
            $result = ConvertFrom-Lua -InputObject $luaContent
            $result.level1.level2.level3.level4.level5.value | Should -Be 'deep'
            $result.level1.level2.level3.level4.level5.count | Should -Be 42
            $result.level1.level2.level3.level4.level5.active | Should -BeTrue
        }

        It 'Parses sibling at level 4' {
            $result = ConvertFrom-Lua -InputObject $luaContent
            $result.level1.level2.level3.level4.sibling | Should -Be 'level4-sibling'
        }

        It 'Parses arrays of objects inside deep nesting' {
            $result = ConvertFrom-Lua -InputObject $luaContent
            $items = $result.level1.level2.level3.items
            $items.Count | Should -Be 2
            $items[0].id | Should -Be 1
            $items[0].name | Should -Be 'item1'
            $items[0].tags.Count | Should -Be 2
            $items[0].tags[0] | Should -Be 'alpha'
            $items[1].tags[0] | Should -Be 'gamma'
        }

        It 'Parses nested metadata' {
            $result = ConvertFrom-Lua -InputObject $luaContent
            $result.level1.level2.metadata.created | Should -Be '2024-01-15'
            $result.level1.level2.metadata.modified | Should -Be '2024-06-20'
        }

        It 'Parses deep config with parallel branches' {
            $result = ConvertFrom-Lua -InputObject $luaContent
            $result.config.database.primary.host | Should -Be 'db1.example.com'
            $result.config.database.primary.port | Should -Be 5432
            $result.config.database.primary.options.ssl | Should -BeTrue
            $result.config.database.primary.options.pool.min | Should -Be 5
            $result.config.database.primary.options.pool.max | Should -Be 20

            $result.config.database.replica.host | Should -Be 'db2.example.com'
            $result.config.database.replica.options.pool.min | Should -Be 2
            $result.config.database.replica.options.pool.idle | Should -Be 30000
        }

        It 'Parses cache config with array of backend objects' {
            $result = ConvertFrom-Lua -InputObject $luaContent
            $result.config.cache.enabled | Should -BeTrue
            $result.config.cache.ttl | Should -Be 3600
            $result.config.cache.backends.Count | Should -Be 2
            $result.config.cache.backends[0].type | Should -Be 'memory'
            $result.config.cache.backends[0].maxSize | Should -Be 1048576
            $result.config.cache.backends[1].type | Should -Be 'redis'
            $result.config.cache.backends[1].host | Should -Be 'cache.example.com'
        }

        It 'Parses matrix (array of arrays)' {
            $result = ConvertFrom-Lua -InputObject $luaContent
            $result.matrix.Count | Should -Be 3
            $result.matrix[0].Count | Should -Be 3
            $result.matrix[0][0] | Should -Be 1
            $result.matrix[1][1] | Should -Be 5
            $result.matrix[2][2] | Should -Be 9
        }

        It 'Parses mixed-depth structure' {
            $result = ConvertFrom-Lua -InputObject $luaContent
            $result.mixedDepth.shallow | Should -Be 'yes'
            $result.mixedDepth.deep.deeper.deepest.array.Count | Should -Be 3
            $result.mixedDepth.deep.deeper.deepest.array[0] | Should -Be 10
            $result.mixedDepth.deep.deeper.deepest.nested.flag | Should -BeFalse
            $result.mixedDepth.deep.deeper.deepest.nested.label | Should -Be 'end'
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

        It 'Escapes carriage returns' {
            $result = ConvertTo-Lua -InputObject "a`rb"
            $result | Should -Be '"a\rb"'
        }
    }

    Context 'Null omission' {
        It 'Omits $null values from hashtable output' {
            $result = ConvertTo-Lua -InputObject ([ordered]@{ a = 1; b = $null; c = 3 }) -Compress
            $result | Should -Be '{a=1,c=3}'
        }

        It 'Omits $null values from PSCustomObject output' {
            $obj = [PSCustomObject]@{ name = 'test'; removed = $null; value = 5 }
            $result = ConvertTo-Lua -InputObject $obj -Compress
            $result | Should -Match 'name="test"'
            $result | Should -Match 'value=5'
            $result | Should -Not -Match 'removed'
        }

        It 'All-null hashtable becomes empty table' {
            $result = ConvertTo-Lua -InputObject @{ a = $null; b = $null } -Compress
            $result | Should -Be '{}'
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

    Context 'Reserved words as keys' {
        It 'Uses bracket notation for Lua reserved word keys' {
            $result = ConvertTo-Lua -InputObject ([ordered]@{ 'return' = 1; 'end' = 2; name = 'ok' }) -Compress
            $result | Should -Match '\["return"\]=1'
            $result | Should -Match '\["end"\]=2'
            $result | Should -Match 'name="ok"'
        }

        It 'Uses bracket notation for "true" as a key' {
            $result = ConvertTo-Lua -InputObject @{ 'true' = 'yes' } -Compress
            $result | Should -Be '{["true"]="yes"}'
        }

        It 'Uses bracket notation for "nil" as a key' {
            $result = ConvertTo-Lua -InputObject @{ 'nil' = 'nothing' } -Compress
            $result | Should -Be '{["nil"]="nothing"}'
        }

        It 'Uses bracket notation for "while" as a key' {
            $result = ConvertTo-Lua -InputObject @{ 'while' = 'loop' } -Compress
            $result | Should -Be '{["while"]="loop"}'
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

    Context 'Depth limiting' {
        It 'Serializes up to max depth without warning' {
            $obj = [ordered]@{ a = [ordered]@{ b = 1 } }
            # Depth 2 allows two levels of nesting
            $result = ConvertTo-Lua -InputObject $obj -Depth 2 -Compress
            $result | Should -Be '{a={b=1}}'
        }

        It 'Emits warning and truncates when depth exceeded' {
            $obj = [ordered]@{ a = [ordered]@{ b = [ordered]@{ c = 1 } } }
            $result = ConvertTo-Lua -InputObject $obj -Depth 1 -Compress 3>&1
            # The result should contain the warning and the truncated output
            $warnings = @($result | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
            $warnings.Count | Should -BeGreaterThan 0
        }

        It 'Depth 0 serializes only primitives, truncates complex types' {
            $obj = [ordered]@{ a = 1 }
            $result = ConvertTo-Lua -InputObject $obj -Depth 0 -Compress 3>&1
            $warnings = @($result | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
            $warnings.Count | Should -BeGreaterThan 0
        }
    }

    Context 'AsArray' {
        It 'Wraps a single string value in a sequence table' {
            $result = ConvertTo-Lua -InputObject 'hello' -AsArray -Compress
            $result | Should -Be '{"hello"}'
        }

        It 'Wraps a single integer in a sequence table' {
            $result = ConvertTo-Lua -InputObject 42 -AsArray -Compress
            $result | Should -Be '{42}'
        }

        It 'Does not double-wrap an array' {
            $result = ConvertTo-Lua -InputObject @(1, 2) -AsArray -Compress
            $result | Should -Be '{1,2}'
        }
    }

    Context 'EnumsAsStrings' {
        It 'Serializes enum as numeric value by default' {
            $result = ConvertTo-Lua -InputObject ([System.DayOfWeek]::Monday)
            $result | Should -Be '1'
        }

        It 'Serializes enum as string with -EnumsAsStrings' {
            $result = ConvertTo-Lua -InputObject ([System.DayOfWeek]::Monday) -EnumsAsStrings
            $result | Should -Be '"Monday"'
        }
    }

    Context 'Indentation' {
        It 'Uses 4-space indentation by default' {
            $result = ConvertTo-Lua -InputObject @(1)
            $lines = $result -split "`n"
            $lines[1] | Should -Match '^    1$'
        }

        It 'Compress removes all whitespace and newlines' {
            $result = ConvertTo-Lua -InputObject ([ordered]@{ a = 1; b = 2 }) -Compress
            $result | Should -Not -Match "`n"
            $result | Should -Not -Match '  '
        }
    }

    Context 'Pipeline input' {
        It 'Accepts input from the pipeline' {
            $result = @{ x = 10 } | ConvertTo-Lua -Compress
            $result | Should -Be '{x=10}'
        }
    }
}

Describe 'Round-trip conversion' {
    BeforeAll {
        $dataPath = Join-Path -Path $PSScriptRoot -ChildPath 'data'
    }

    Context 'Simple round-trips' {
        It 'Round-trips a simple hashtable' {
            $original = [ordered]@{ name = 'test'; count = 5; active = $true }
            $lua = ConvertTo-Lua -InputObject $original
            $result = ConvertFrom-Lua -InputObject $lua -AsHashtable
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

        It 'Round-trips a string array' {
            $original = @('alpha', 'beta', 'gamma')
            $lua = ConvertTo-Lua -InputObject $original
            $result = ConvertFrom-Lua -InputObject $lua
            $result.Count | Should -Be 3
            $result[0] | Should -Be 'alpha'
            $result[2] | Should -Be 'gamma'
        }

        It 'Round-trips booleans in an array' {
            $original = @($true, $false, $true)
            $lua = ConvertTo-Lua -InputObject $original
            $result = ConvertFrom-Lua -InputObject $lua
            $result[0] | Should -BeTrue
            $result[1] | Should -BeFalse
            $result[2] | Should -BeTrue
        }

        It 'Round-trips empty hashtable' {
            $original = [ordered]@{}
            $lua = ConvertTo-Lua -InputObject $original
            $result = ConvertFrom-Lua -InputObject $lua -AsHashtable
            $result.Count | Should -Be 0
        }

        It 'Round-trips empty array' {
            $original = @()
            $lua = ConvertTo-Lua -InputObject $original
            $result = ConvertFrom-Lua -InputObject $lua -AsHashtable
            $result.Count | Should -Be 0
        }
    }

    Context 'Nested round-trips' {
        It 'Round-trips 2-level nested hashtable' {
            $original = [ordered]@{
                server  = 'localhost'
                port    = 8080
                options = [ordered]@{
                    debug   = $false
                    verbose = $true
                }
            }
            $lua = ConvertTo-Lua -InputObject $original
            $result = ConvertFrom-Lua -InputObject $lua -AsHashtable
            $result.server | Should -Be 'localhost'
            $result.port | Should -Be 8080
            $result.options.debug | Should -BeFalse
            $result.options.verbose | Should -BeTrue
        }

        It 'Round-trips 3-level nested structure' {
            $original = [ordered]@{
                a = [ordered]@{
                    b = [ordered]@{
                        c    = 'deep'
                        num  = 99
                        flag = $true
                    }
                }
            }
            $lua = ConvertTo-Lua -InputObject $original -Depth 5
            $result = ConvertFrom-Lua -InputObject $lua -AsHashtable
            $result.a.b.c | Should -Be 'deep'
            $result.a.b.num | Should -Be 99
            $result.a.b.flag | Should -BeTrue
        }

        It 'Round-trips 5-level deep structure' {
            $original = [ordered]@{
                l1 = [ordered]@{
                    l2 = [ordered]@{
                        l3 = [ordered]@{
                            l4 = [ordered]@{
                                l5 = 'bottom'
                            }
                        }
                    }
                }
            }
            $lua = ConvertTo-Lua -InputObject $original -Depth 10
            $result = ConvertFrom-Lua -InputObject $lua -AsHashtable
            $result.l1.l2.l3.l4.l5 | Should -Be 'bottom'
        }

        It 'Round-trips nested arrays of arrays' {
            $original = @(
                @(1, 2, 3),
                @(4, 5, 6),
                @(7, 8, 9)
            )
            $lua = ConvertTo-Lua -InputObject $original -Depth 5
            $result = ConvertFrom-Lua -InputObject $lua
            $result.Count | Should -Be 3
            $result[0].Count | Should -Be 3
            $result[0][0] | Should -Be 1
            $result[1][1] | Should -Be 5
            $result[2][2] | Should -Be 9
        }

        It 'Round-trips array of hashtables' {
            $original = @(
                [ordered]@{ id = 1; name = 'first' },
                [ordered]@{ id = 2; name = 'second' }
            )
            $lua = ConvertTo-Lua -InputObject $original -Depth 5
            $result = ConvertFrom-Lua -InputObject $lua
            $result.Count | Should -Be 2
            $result[0].id | Should -Be 1
            $result[0].name | Should -Be 'first'
            $result[1].id | Should -Be 2
            $result[1].name | Should -Be 'second'
        }

        It 'Round-trips hashtable with array values at multiple levels' {
            $original = [ordered]@{
                tags   = @('a', 'b', 'c')
                nested = [ordered]@{
                    scores = @(10, 20, 30)
                    deep   = [ordered]@{
                        items = @('x', 'y')
                    }
                }
            }
            $lua = ConvertTo-Lua -InputObject $original -Depth 10
            $result = ConvertFrom-Lua -InputObject $lua -AsHashtable
            $result.tags.Count | Should -Be 3
            $result.tags[0] | Should -Be 'a'
            $result.nested.scores.Count | Should -Be 3
            $result.nested.scores[1] | Should -Be 20
            $result.nested.deep.items.Count | Should -Be 2
            $result.nested.deep.items[0] | Should -Be 'x'
        }
    }

    Context 'Complex deep structure round-trips' {
        It 'Round-trips a full config-like structure (5+ levels)' {
            $original = [ordered]@{
                app = [ordered]@{
                    name    = 'MyApp'
                    version = '2.0'
                    modules = [ordered]@{
                        auth = [ordered]@{
                            enabled  = $true
                            provider = [ordered]@{
                                type     = 'oauth'
                                settings = [ordered]@{
                                    clientId = 'abc123'
                                    scopes   = @('read', 'write', 'admin')
                                }
                            }
                        }
                        logging = [ordered]@{
                            level   = 'info'
                            outputs = @(
                                [ordered]@{ type = 'console'; colored = $true },
                                [ordered]@{ type = 'file'; path = '/var/log/app.log' }
                            )
                        }
                    }
                }
                database = [ordered]@{
                    connections = @(
                        [ordered]@{
                            name    = 'primary'
                            options = [ordered]@{
                                pool = [ordered]@{ min = 5; max = 20 }
                            }
                        }
                    )
                }
            }
            $lua = ConvertTo-Lua -InputObject $original -Depth 20
            $result = ConvertFrom-Lua -InputObject $lua -AsHashtable
            $result.app.name | Should -Be 'MyApp'
            $result.app.modules.auth.enabled | Should -BeTrue
            $result.app.modules.auth.provider.type | Should -Be 'oauth'
            $result.app.modules.auth.provider.settings.clientId | Should -Be 'abc123'
            $result.app.modules.auth.provider.settings.scopes.Count | Should -Be 3
            $result.app.modules.auth.provider.settings.scopes[2] | Should -Be 'admin'
            $result.app.modules.logging.outputs.Count | Should -Be 2
            $result.app.modules.logging.outputs[0].type | Should -Be 'console'
            $result.app.modules.logging.outputs[1].path | Should -Be '/var/log/app.log'
            $result.database.connections[0].name | Should -Be 'primary'
            $result.database.connections[0].options.pool.min | Should -Be 5
        }

        It 'Round-trips from JSON DeepStructure to Lua and back' {
            $jsonPath = Join-Path $dataPath 'DeepStructure.json'
            $expected = Get-Content -Path $jsonPath -Raw | ConvertFrom-Json
            $lua = ConvertTo-Lua -InputObject $expected -Depth 20
            $result = ConvertFrom-Lua -InputObject $lua
            $result.level1.level2.level3.level4.level5.value | Should -Be $expected.level1.level2.level3.level4.level5.value
            $result.level1.level2.level3.level4.level5.count | Should -Be $expected.level1.level2.level3.level4.level5.count
            $result.level1.level2.level3.level4.sibling | Should -Be $expected.level1.level2.level3.level4.sibling
            $result.config.database.primary.options.pool.max | Should -Be $expected.config.database.primary.options.pool.max
            $result.config.database.replica.options.pool.idle | Should -Be $expected.config.database.replica.options.pool.idle
            $result.config.cache.backends.Count | Should -Be 2
            $result.matrix.Count | Should -Be 3
            $result.matrix[1][1] | Should -Be 5
            $result.mixedDepth.deep.deeper.deepest.nested.flag | Should -BeFalse
        }

        It 'Round-trips from JSON TestStructure to Lua and back' {
            $jsonPath = Join-Path $dataPath 'TestStructure.json'
            $expected = Get-Content -Path $jsonPath -Raw | ConvertFrom-Json
            $lua = ConvertTo-Lua -InputObject $expected -Depth 10
            $result = ConvertFrom-Lua -InputObject $lua
            $result.name | Should -Be $expected.name
            $result.enabled | Should -Be $expected.enabled
            $result.maxRetries | Should -Be $expected.maxRetries
            $result.authors.Count | Should -Be $expected.authors.Count
            $result.unitframes.colors.health.Count | Should -Be 3
            $result.actionbars.bar1.buttons | Should -Be $expected.actionbars.bar1.buttons
        }

        It 'Round-trips compressed output' {
            $original = [ordered]@{
                a = @(1, 2)
                b = [ordered]@{ c = 'x' }
            }
            $lua = ConvertTo-Lua -InputObject $original -Compress -Depth 5
            $result = ConvertFrom-Lua -InputObject $lua -AsHashtable
            $result.a.Count | Should -Be 2
            $result.a[0] | Should -Be 1
            $result.b.c | Should -Be 'x'
        }

        It 'Round-trips with -NoEnumerate preserving array wrapper' {
            $lua = '{1, 2, 3}'
            $result = ConvertFrom-Lua -InputObject $lua -NoEnumerate
            $roundTripped = ConvertTo-Lua -InputObject $result -Compress
            $roundTripped | Should -Be '{1,2,3}'
        }

        It 'Round-trips strings with special characters' {
            $original = [ordered]@{
                escaped   = "line1`nline2`ttab"
                quoted    = 'she said "hi"'
                backslash = 'C:\path\to\file'
            }
            $lua = ConvertTo-Lua -InputObject $original -Depth 5
            $result = ConvertFrom-Lua -InputObject $lua -AsHashtable
            $result.escaped | Should -Be "line1`nline2`ttab"
            $result.quoted | Should -Be 'she said "hi"'
            $result.backslash | Should -Be 'C:\path\to\file'
        }

        It 'Round-trips unicode strings' {
            $original = [ordered]@{
                greeting = 'Héllo Wörld'
                emoji    = 'test'
                cjk      = '日本語'
            }
            $lua = ConvertTo-Lua -InputObject $original -Depth 5
            $result = ConvertFrom-Lua -InputObject $lua -AsHashtable
            $result.greeting | Should -Be 'Héllo Wörld'
            $result.cjk | Should -Be '日本語'
        }

        It 'Round-trips deeply nested array-of-objects-with-arrays' {
            $original = @(
                [ordered]@{
                    name  = 'group1'
                    items = @(
                        [ordered]@{ id = 1; tags = @('a', 'b') },
                        [ordered]@{ id = 2; tags = @('c') }
                    )
                },
                [ordered]@{
                    name  = 'group2'
                    items = @(
                        [ordered]@{ id = 3; tags = @('d', 'e', 'f') }
                    )
                }
            )
            $lua = ConvertTo-Lua -InputObject $original -Depth 10
            $result = ConvertFrom-Lua -InputObject $lua
            $result.Count | Should -Be 2
            $result[0].name | Should -Be 'group1'
            $result[0].items.Count | Should -Be 2
            $result[0].items[0].tags.Count | Should -Be 2
            $result[0].items[0].tags[0] | Should -Be 'a'
            $result[1].items[0].tags.Count | Should -Be 3
            $result[1].items[0].tags[2] | Should -Be 'f'
        }
    }
}
