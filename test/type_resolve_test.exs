defmodule TypeResolveTest do
  use ExUnit.Case
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
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, {:list, [{:integer, []}]}}
    end

    test "should resolve basic types that usually have args but are not being passed in" do
      quoted_spec = quote(do: list())
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, {:list, []}}
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
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, {:literal, [:an_atom]}}

      quoted_spec = quote(do: true)
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, {:literal, [true]}}

      quoted_spec = quote(do: nil)
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, {:literal, [nil]}}
    end

    test "should resolve literal bitstring specs" do
      quoted_spec = quote(do: <<>>)
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, {:bitstring, [0, nil]}}

      quoted_spec = quote(do: <<_::5>>)
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, {:bitstring, [5, nil]}}

      quoted_spec = quote(do: <<_::_*6>>)
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, {:bitstring, [nil, 6]}}

      quoted_spec = quote(do: <<_::7, _::_*8>>)
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, {:bitstring, [7, 8]}}
    end

    test "should resolve anonymous functions" do
      quoted_spec = quote(do: (() -> atom()))
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, {:function, [{[], {:atom, []}}]}}

      quoted_spec = quote(do: (atom(), integer() -> atom()))

      assert TypeResolve.from_quoted_type(quoted_spec) ==
               {:ok, {:function, [{[{:atom, []}, {:integer, []}], {:atom, []}}]}}

      quoted_spec = quote(do: (... -> atom()))

      assert TypeResolve.from_quoted_type(quoted_spec) ==
               {:ok, {:function, [{:any, {:atom, []}}]}}
    end

    test "should resolve literal integers" do
      quoted_spec = quote(do: 5)
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, {:literal, [5]}}

      quoted_spec = quote(do: 1..10)
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, {:literal, [1..10]}}
    end

    test "should resolve literal lists" do
      quoted_spec = quote(do: [integer()])
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, {:list, [{:integer, []}]}}

      quoted_spec = quote(do: [])
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, {:empty_list, []}}

      quoted_spec = quote(do: [...])
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, {:non_empty_list, [{:any, []}]}}

      quoted_spec = quote(do: [integer(), ...])

      assert TypeResolve.from_quoted_type(quoted_spec) ==
               {:ok, {:non_empty_list, [{:integer, []}]}}

      quoted_spec = quote(do: [some_key: integer(), another_key: float()])

      assert TypeResolve.from_quoted_type(quoted_spec) ==
               {:ok, {:keyword, [some_key: {:integer, []}, another_key: {:float, []}]}}
    end

    test "should resolve literal maps" do
      quoted_spec = quote(do: %{})
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, {:empty_map, []}}

      quoted_spec = quote(do: %{a: integer(), b: float()})

      expected_type =
        {:map, [[{{:literal, [:a]}, {:integer, []}}, {{:literal, [:b]}, {:float, []}}], []]}

      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, expected_type}

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

      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, expected_type}

      quoted_spec = quote(do: %StructA{})
      expected_type = {:struct, [StructA, []]}
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, expected_type}

      defmodule StructB, do: defstruct([])
      quoted_spec = quote(do: %StructB{})
      expected_type = {:struct, [__MODULE__.StructB, []]}
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, expected_type}

      defmodule StructC, do: defstruct([])
      alias StructC, as: StructD
      quoted_spec = quote(do: %StructD{})
      expected_type = {:struct, [__MODULE__.StructC, []]}
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, expected_type}

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

      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, expected_type}
    end

    test "should resolve literal tuples" do
      quoted_spec = quote(do: {})
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, {:tuple, []}}

      quoted_spec = quote(do: {integer()})
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, {:tuple, [{:integer, []}]}}

      quoted_spec = quote(do: {integer(), atom()})

      assert TypeResolve.from_quoted_type(quoted_spec) ==
               {:ok, {:tuple, [{:integer, []}, {:atom, []}]}}

      quoted_spec = quote(do: {integer(), atom(), float()})

      assert TypeResolve.from_quoted_type(quoted_spec) ==
               {:ok, {:tuple, [{:integer, []}, {:atom, []}, {:float, []}]}}
    end
  end

  describe "remote types" do
    test "should be able to resolve remote types" do
      quoted_spec = quote(do: String.t())
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, {:binary, []}}

      quoted_spec = quote(do: String.grapheme())
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, {:binary, []}}

      quoted_spec = quote(do: Module.definition())

      assert TypeResolve.from_quoted_type(quoted_spec) ==
               {:ok, {:tuple, [{:atom, []}, {:arity, []}]}}

      quoted_spec = quote(do: Module.def_kind())

      expected_type =
        {:union,
         [
           {:literal, [:def]},
           {:literal, [:defp]},
           {:literal, [:defmacro]},
           {:literal, [:defmacrop]}
         ]}

      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, expected_type}

      quoted_spec = quote(do: Enum.t())
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, {:term, []}}

      quoted_spec = quote(do: Access.t())
      expected_type = {:union, [keyword: [], struct: [], map: [], literal: [nil], any: []]}
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, expected_type}
    end
  end

  describe "User-defined Types" do
    @tag :only
    test "should resolve user defined types" do
      quoted_spec = quote(do: TypeResolve.Private.SampleClient.support())
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, {:binary, []}}

      quoted_spec = quote(do: TypeResolve.Private.SampleClient.status())

      expected_type = {
        :union,
        [
          literal: [:pending],
          literal: [:success],
          literal: [:failure]
        ]
      }

      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, expected_type}

      quoted_spec = quote(do: TypeResolve.Private.SampleClient.t())
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, expected_type}

      quoted_spec = quote(do: TypeResolve.Private.SampleClient.union())

      assert TypeResolve.from_quoted_type(quoted_spec) ==
               {
                 :ok,
                 {
                   :union,
                   [
                     binary: '',
                     literal: [:pending],
                     literal: [:success],
                     literal: [:failure]
                   ]
                 }
               }

      quoted_spec = quote(do: TypeResolve.Private.SampleClient.result())
      expected_type = {:union, [{:tuple, [{:literal, [:ok]}, {:term, []}]}, {:literal, [:error]}]}
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, expected_type}

      quoted_spec = quote(do: TypeResolve.Private.SampleClient.result(atom()))
      expected_type = {:union, [{:tuple, [{:literal, [:ok]}, {:atom, []}]}, {:literal, [:error]}]}
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, expected_type}

      quoted_spec = quote(do: TypeResolve.Private.SampleClient.email())
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, {:binary, []}}

      quoted_spec = quote(do: TypeResolve.Private.SampleClient.pemail())
      assert TypeResolve.from_quoted_type(quoted_spec) == {:ok, {:binary, []}}
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
