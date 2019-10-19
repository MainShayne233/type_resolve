defmodule TypeResolveTest do
  use ExUnit.Case
  doctest TypeResolve

  describe "basic types" do
    test "should resolve basic types" do
      for {type, quoted_spec} <- TypeResolve.__basic_types__() do
        quoted_spec_with_args = apply_args(quoted_spec)

        assert match?(
                 {:ok, {^type, _args}},
                 TypeResolve.resolve(quoted_spec_with_args)
               )
      end
    end

    test "should return :error for invalid quoted spec" do
      assert TypeResolve.resolve(quote(do: kitty())) == :error
    end

    test "should resolve type arguments properly" do
      quoted_spec = quote(do: list(integer()))
      assert TypeResolve.resolve(quoted_spec) == {:ok, {:list, [{:integer, []}]}}
    end

    test "should resolve basic types that usually have args but are not being passed in" do
      quoted_spec = quote(do: list())
      assert TypeResolve.resolve(quoted_spec) == {:ok, {:list, []}}
    end
  end

  describe "built-in types" do
    test "should resolve built-in types" do
      for {type, quoted_spec} <- TypeResolve.__built_in_types__() do
        quoted_spec_with_args = apply_args(quoted_spec)

        assert match?(
                 {:ok, {^type, _args}},
                 TypeResolve.resolve(quoted_spec_with_args)
               )
      end
    end
  end

  describe "literals" do
    test "should resolve literal types" do
      quoted_spec = quote(do: :an_atom)
      assert TypeResolve.resolve(quoted_spec) == {:ok, {:literal, [:an_atom]}}

      quoted_spec = quote(do: true)
      assert TypeResolve.resolve(quoted_spec) == {:ok, {:literal, [true]}}

      quoted_spec = quote(do: nil)
      assert TypeResolve.resolve(quoted_spec) == {:ok, {:literal, [nil]}}
    end

    test "should resolve literal bitstring specs" do
      quoted_spec = quote(do: <<>>)
      assert TypeResolve.resolve(quoted_spec) == {:ok, {:bitstring, [0, nil]}}


      quoted_spec = quote(do: <<_::5>>)
      assert TypeResolve.resolve(quoted_spec) == {:ok, {:bitstring, [5, nil]}}

      quoted_spec = quote(do: <<_::_*6>>)
      assert TypeResolve.resolve(quoted_spec) == {:ok, {:bitstring, [nil, 6]}}

      quoted_spec = quote(do: <<_::7, _::_*8>>)
      assert TypeResolve.resolve(quoted_spec) == {:ok, {:bitstring, [7, 8]}}
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
