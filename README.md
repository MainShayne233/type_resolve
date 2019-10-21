# TypeResolve

## TODOs

- Fix infinite recursion bug (i.e. Macro.input())

## Definitions

**Spec**: A type definition in source format (i.e. `integer()` or `String.t()`)

**SpecGenerator**: A spec definition w/ > 0 arity that requires arguments to produce a proper type (i.e. `list(type)`)

**SpecInstance**: A spec definition that either has 0 arity or has had type arguments applied to it (i.e. `integer()` or `list(integer())`)

**Quoted Spec**: A spec, but when in it's AST form (i.e. `{:integer, [], []}` or `{{:., [], [{:__aliases__, [alias: false], [:String]}, :t]}, [], []}`)

**Type**: The runtime value representing a spec (i.e. `:integer`)

**Resolve**: Get the type for a spec (i.e. `resolve(integer()) == :integer`)
