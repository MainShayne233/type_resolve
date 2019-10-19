# TypeResolve

## Definitions

**Spec**: A type definition in source format (i.e. `integer()` or `String.t()`)

**Quoted Spec**: A spec, but when in it's AST form (i.e. `{:integer, [], []}` or `{{:., [], [{:__aliases__, [alias: false], [:String]}, :t]}, [], []}`)

**Type**: The runtime value representing a spec (i.e. `:integer`)

**Resolve**: Get the type for a spec (i.e. `resolve(integer()) == :integer`)
