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

  @built_in_types %{
    term: quote(do: term()),
    arity: quote(do: arity()),
    as_boolean: quote(do: as_boolean(t)),
    binary: quote(do: binary()),
    bitstring: quote(do: bitstring()),
    boolean: quote(do: boolean()),
    byte: quote(do: byte()),
    char: quote(do: char()),
    charlist: quote(do: charlist()),
    nonempty_charlist: quote(do: nonempty_charlist()),
    fun: quote(do: fun()),
    function: quote(do: function()),
    identifier: quote(do: identifier()),
    iodata: quote(do: iodata()),
    iolist: quote(do: iolist()),
    keyword: quote(do: keyword(t)),
    list: quote(do: list()),
    nonempty_list: quote(do: nonempty_list()),
    maybe_improper_list: quote(do: maybe_improper_list()),
    nonempty_maybe_improper_list: quote(do: nonempty_maybe_improper_list()),
    mfa: quote(do: mfa()),
    module: quote(do: module()),
    no_return: quote(do: no_return()),
    node: quote(do: node()),
    number: quote(do: number()),
    struct: quote(do: struct()),
    timeout: quote(do: timeout())
  }

  @spec __basic_types__ :: %{required(type_name) => quoted_spec()}
  def __basic_types__, do: @basic_types

  @spec __built_in_types__ :: %{required(type_name) => quoted_spec()}
  def __built_in_types__, do: @built_in_types

  @spec resolve(quoted_spec()) :: result(type())

  for {type, {quoted_spec_name, _, _params}} <- Map.merge(@basic_types, @built_in_types) do
    def resolve({unquote(quoted_spec_name), _, params}) do
      with {:ok, resolved_params} <- maybe_map(params, &resolve/1) do
        {:ok, {unquote(type), resolved_params}}
      end
    end
  end

  def resolve(atom) when is_atom(atom), do: {:ok, {:literal, [atom]}}

  def resolve({:<<>>, [], args}) do
    {size, unit} =
      case args do
        [] ->
          {0, nil}

        [{:"::", _, [{:_, _, _}, size]}] when is_integer(size) ->
          {size, nil}

        [{:"::", _, [{:_, _, _}, {:*, _, [{:_, _, _}, unit]}]}] when is_integer(unit) ->
          {nil, unit}

        [{:"::", _, [{:_, _, _}, size]}, {:"::", _, [{:_, _, _}, {:*, _, [{:_, _, _}, unit]}]}]
        when is_integer(size) and is_integer(unit) ->
          {size, unit}
      end

    {:ok, {:bitstring, [size, unit]}}
  end

  def resolve(other) do
    IO.inspect(other, label: "Failed to resolve")
    :error
  end

  @spec maybe_map(Enumerable.t(), (term -> result(term))) :: {:ok, list(term())} | :error
  defp maybe_map(enum, map) do
    Enum.reduce_while(enum, [], fn value, acc ->
      case map.(value) do
        {:ok, mapped_value} -> {:cont, [mapped_value | acc]}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      acc when is_list(acc) -> {:ok, Enum.reverse(acc)}
      :error -> :error
    end
  end
end
