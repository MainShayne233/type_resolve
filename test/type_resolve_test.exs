defmodule TypeResolveTest do
  use ExUnit.Case
  use TypeResolve.TestUtil
  doctest TypeResolve

  describe "basic types" do
    test "should resolve basic types" do
      for {type, quoted_spec} <- TypeResolve.__basic_types__() do
        quoted_spec_with_args = apply_args(quoted_spec)

        assert match?(
                 {:ok, {^type, _args}},
                 TypeResolve.from_quoted_type(quoted_spec_with_args)
               )
      end
    end

    test "should return :error for invalid quoted spec" do
      assert TypeResolve.from_quoted_type(quote(do: kitty())) == :error
    end

    test "should resolve type arguments properly" do
      quoted_spec = quote(do: list(integer()))
      expected_type = {:list, [{:integer, []}]}
      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve basic types that usually have args but are not being passed in" do
      quoted_spec = quote(do: list())
      expected_type = {:list, []}
      assert_resolve(quoted_spec, expected_type)
    end
  end

  describe "built-in types" do
    test "should resolve built-in types" do
      for {type, quoted_spec} <- TypeResolve.__built_in_types__() do
        quoted_spec_with_args = apply_args(quoted_spec)

        assert match?(
                 {:ok, {^type, _args}},
                 TypeResolve.from_quoted_type(quoted_spec_with_args)
               )
      end
    end
  end

  describe "literals" do
    test "should resolve literal types" do
      quoted_spec = quote(do: :an_atom)
      expected_type = {:literal, [:an_atom]}
      assert_resolve(quoted_spec, expected_type)

      quoted_spec = quote(do: true)
      expected_type = {:literal, [true]}
      assert_resolve(quoted_spec, expected_type)

      quoted_spec = quote(do: nil)
      expected_type = {:literal, [nil]}
      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve an empty bitstring spec" do
      quoted_spec = quote(do: <<>>)
      expected_type = {:bitstring, [0, nil]}
      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve a bitstring spec with a size specified" do
      quoted_spec = quote(do: <<_::5>>)
      expected_type = {:bitstring, [5, nil]}
      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve a bitstring spec with a unit specified" do
      quoted_spec = quote(do: <<_::_*6>>)
      expected_type = {:bitstring, [nil, 6]}
      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve a bitstring spec with both a size and unit specified" do
      quoted_spec = quote(do: <<_::7, _::_*8>>)
      expected_type = {:bitstring, [7, 8]}
      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve 0-arity anonymous functions" do
      quoted_spec = quote(do: (() -> atom()))
      expected_type = {:function, [{[], {:atom, []}}]}
      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve 1+-arity anonymous functions" do
      quoted_spec = quote(do: (atom(), integer() -> atom()))
      expected_type = {:function, [{[{:atom, []}, {:integer, []}], {:atom, []}}]}
      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve any-arity anonymous functions" do
      quoted_spec = quote(do: (... -> atom()))
      expected_type = {:function, [{:any, {:atom, []}}]}
      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve literal integers" do
      quoted_spec = quote(do: 5)
      expected_type = {:literal, [5]}
      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve literal ranges" do
      quoted_spec = quote(do: 1..10)
      expected_type = {:literal, [1..10]}
      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve literal lists of a single type" do
      quoted_spec = quote(do: [integer()])
      expected_type = {:list, [{:integer, []}]}
      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve empty lists" do
      quoted_spec = quote(do: [])
      expected_type = {:empty_list, []}
      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve non-empty lists of any type" do
      quoted_spec = quote(do: [...])
      expected_type = {:non_empty_list, [{:any, []}]}
      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve non-empty lists of a specific type" do
      quoted_spec = quote(do: [integer(), ...])
      expected_type = {:non_empty_list, [{:integer, []}]}
      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve keyword lists" do
      quoted_spec = quote(do: [some_key: integer(), another_key: float()])
      expected_type = {:keyword, [some_key: {:integer, []}, another_key: {:float, []}]}
      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve literal empty maps" do
      quoted_spec = quote(do: %{})
      expected_type = {:empty_map, []}
      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve literal maps with literal keys" do
      quoted_spec = quote(do: %{a: integer(), b: float()})

      expected_type =
        {:map, [[{{:literal, [:a]}, {:integer, []}}, {{:literal, [:b]}, {:float, []}}], []]}

      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve literal maps with required/optional kvs" do
      quoted_spec =
        quote(
          do: %{
            required(atom()) => integer(),
            required(integer()) => float(),
            optional(atom()) => atom()
          }
        )

      expected_type =
        {:map,
         [
           [{{:atom, []}, {:integer, []}}, {{:integer, []}, {:float, []}}],
           [{{:atom, []}, {:atom, []}}]
         ]}

      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve undefined structs" do
      quoted_spec = quote(do: %StructA{})
      expected_type = {:struct, [StructA, []]}
      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve defined structs" do
      defmodule StructB, do: defstruct([])
      quoted_spec = quote(do: %StructB{})
      expected_type = {:struct, [__MODULE__.StructB, []]}
      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve defined structs that have been aliases" do
      defmodule StructC, do: defstruct([])
      alias StructC, as: StructD
      quoted_spec = quote(do: %StructD{})
      expected_type = {:struct, [__MODULE__.StructC, []]}
      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve defined structs with defined kvs" do
      quoted_spec =
        quote(
          do: %StructE{
            some_key: atom(),
            another_key: integer()
          }
        )

      expected_type =
        {:struct,
         [
           StructE,
           [{{:literal, [:some_key]}, {:atom, []}}, {{:literal, [:another_key]}, {:integer, []}}]
         ]}

      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve literal empty tuples" do
      quoted_spec = quote(do: {})
      expected_type = {:tuple, []}
      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve literal tuples with 1 element" do
      quoted_spec = quote(do: {integer()})
      expected_type = {:tuple, [{:integer, []}]}
      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve literal tuples with 2 elements" do
      quoted_spec = quote(do: {integer(), atom()})
      expected_type = {:tuple, [{:integer, []}, {:atom, []}]}
      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve literal tuples with 3 elements" do
      quoted_spec = quote(do: {integer(), atom(), float()})
      expected_type = {:tuple, [{:integer, []}, {:atom, []}, {:float, []}]}
      assert_resolve(quoted_spec, expected_type)
    end
  end

  describe "remote types" do
    test "should resolve a remote type that simply points to a plain type" do
      quoted_spec = quote(do: String.t())
      expected_type = {:binary, []}
      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve a remote type that points to another remote type" do
      quoted_spec = quote(do: String.grapheme())
      expected_type = {:binary, []}
      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve a remote type that points to a non-trivial type" do
      quoted_spec = quote(do: Module.definition())
      expected_type = {:tuple, [{:atom, []}, {:arity, []}]}
      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve a remote type that points to a union type" do
      quoted_spec = quote(do: Module.def_kind())

      expected_type =
        {:union,
         [
           {:literal, [:def]},
           {:literal, [:defp]},
           {:literal, [:defmacro]},
           {:literal, [:defmacrop]}
         ]}

      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve a remote type that points to another remote type defined in another module" do
      quoted_spec = quote(do: Enum.t())
      expected_type = {:term, []}
      assert_resolve(quoted_spec, expected_type)
    end

    test "should resolve a remote type is a union of other remote types" do
      quoted_spec = quote(do: Access.t())
      expected_type = {:union, [keyword: [], struct: [], map: [], literal: [nil], any: []]}
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, expected_type}
    end
  end

  describe "User-defined Types" do
    test "should resolve user defined types" do
      quoted_spec = quote(do: TypeResolve.Private.SampleClient.support())
      expected_type = {:binary, []}
      assert_resolve(quoted_spec, expected_type)

      quoted_spec = quote(do: TypeResolve.Private.SampleClient.status())

      expected_type = {
        :union,
        [
          literal: [:pending],
          literal: [:success],
          literal: [:failure]
        ]
      }

      assert_resolve(quoted_spec, expected_type)

      quoted_spec = quote(do: TypeResolve.Private.SampleClient.t())
      assert_resolve(quoted_spec, expected_type)

      quoted_spec = quote(do: TypeResolve.Private.SampleClient.union())

      expected_type = {
        :union,
        [
          binary: '',
          literal: [:pending],
          literal: [:success],
          literal: [:failure]
        ]
      }

      assert_resolve(quoted_spec, expected_type)

      quoted_spec = quote(do: TypeResolve.Private.SampleClient.result())
      expected_type = {:union, [{:tuple, [{:literal, [:ok]}, {:term, []}]}, {:literal, [:error]}]}
      assert_resolve(quoted_spec, expected_type)

      quoted_spec = quote(do: TypeResolve.Private.SampleClient.result(atom()))
      expected_type = {:union, [{:tuple, [{:literal, [:ok]}, {:atom, []}]}, {:literal, [:error]}]}
      assert_resolve(quoted_spec, expected_type)

      quoted_spec = quote(do: TypeResolve.Private.SampleClient.email())
      expected_type = {:binary, []}
      assert_resolve(quoted_spec, expected_type)

      quoted_spec = quote(do: TypeResolve.Private.SampleClient.pemail())
      expected_type = {:binary, []}
      assert_resolve(quoted_spec, expected_type)
    end
  end

  defp apply_args({quoted_spec_name, options, params}) do
    args =
      Enum.take(
        [
          quote(do: integer()),
          quote(do: float()),
          quote(do: atom())
        ],
        length(params)
      )

    {quoted_spec_name, options, args}
  end
end
