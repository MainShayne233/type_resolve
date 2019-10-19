defmodule TypeResolve do
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

  def __basic_types__, do: @basic_types

  for {type, quoted_spec} <- @basic_types do
    def resolve(unquote(Macro.escape(quoted_spec))), do: {:ok, unquote(type)}
  end
end
