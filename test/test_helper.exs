defmodule TypeResolve.TestUtil do
  defmacro __using__([]) do
    quote do
      import TypeResolve.TestUtil, only: [assert_resolve: 2]
    end
  end

  @doc """
  A helper that will assert a quoted type will get resolved to an expected type.
  """
  defmacro assert_resolve(quoted_spec, expected_type) do
    quote do
      assert TypeResolve.from_quoted_type(unquote(quoted_spec)) == {:ok, unquote(expected_type)}
    end
  end
end

ExUnit.start()
