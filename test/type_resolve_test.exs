defmodule TypeResolveTest do
  use ExUnit.Case
  doctest TypeResolve

  test "should resolve basic types" do
    for {type, quoted_spec} <- TypeResolve.__basic_types__() do
      assert TypeResolve.resolve(quoted_spec) == {:ok, type}
    end
  end

  test "should return :error for invalid quoted spec" do
    assert TypeResolve.resolve(quote(do: kitty())) == :error
  end
end
