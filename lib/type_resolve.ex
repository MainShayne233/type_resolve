defmodule TypeResolve do
  @type result(data) :: {:ok, data} | :error
  @type quoted_spec :: Macro.t()
  @type type_name :: atom()
  @type type_args :: [type()]
  @type type :: {type_name(), type_args()}
  @type basic_type :: term()

  @basic_types %{
    any: quote(do: any()),
    none: quote(do: none()),
    atom: quote(do: atom()),
    map: quote(do: map()),
    pid: quote(do: pid()),
    port: quote(do: port()),
    reference: quote(do: reference()),
    struct: quote(do: struct()),
    tuple: quote(do: tuple()),
    float: quote(do: float()),
    integer: quote(do: integer()),
    neg_integer: quote(do: neg_integer()),
    non_neg_integer: quote(do: non_neg_integer()),
    pos_integer: quote(do: pos_integer()),
    list: quote(do: list(type)),
    nonempty_list: quote(do: nonempty_list(type)),
    maybe_improper_list: quote(do: maybe_improper_list(type1, type2)),
    nonempty_improper_list: quote(do: nonempty_improper_list(type1, type2)),
    nonempty_maybe_improper_list: quote(do: nonempty_maybe_improper_list(type1, type2))
  }

  @spec __basic_types__ :: %{required(type_name) => quoted_spec()}
  def __basic_types__, do: @basic_types

  @spec resolve(quoted_spec()) :: result(type())

  for {type, quoted_spec} <- @basic_types do
    def resolve(unquote(Macro.escape(quoted_spec))), do: {:ok, unquote(type)}
  end

  def resolve(other) do
    IO.inspect(other, label: "Failed to resolve")
    :error
  end
end
