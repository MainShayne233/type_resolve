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

  defguardp is_literal(value) when is_atom(value) or is_integer(value)

  def resolve(literal) when is_literal(literal), do: {:ok, {:literal, [literal]}}

  def resolve({:.., _, [min, max]}) when is_integer(min) and is_integer(max) do
    {:ok, {:literal, [min..max]}}
  end

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

  def resolve([{:->, [], [[{:..., _, _}], return_spec]}]) do
    with {:ok, return_type} <- resolve(return_spec) do
      {:ok, {:function, [{:any, return_type}]}}
    end
  end

  def resolve([{:->, [], [param_specs, return_spec]}]) do
    with {:ok, param_types} <- maybe_map(param_specs, &resolve/1),
         {:ok, return_type} <- resolve(return_spec) do
      {:ok, {:function, [{param_types, return_type}]}}
    end
  end

  def resolve([quoted_item_spec, {:..., [], _}]) do
    with {:ok, item_type} <- resolve(quoted_item_spec), do: {:ok, {:non_empty_list, [item_type]}}
  end

  def resolve([{:..., [], _}]), do: {:ok, {:non_empty_list, [{:any, []}]}}

  def resolve([]), do: {:ok, {:empty_list, []}}

  def resolve([:...]), do: {:ok, {:empty_list, []}}

  def resolve([{key, _quoted_item_spec} | _] = quoted_keyword_spec) when is_atom(key) do
    quoted_keyword_spec
    |> maybe_map(fn {key, quoted_spec} ->
      with {:ok, type} <- resolve(quoted_spec), do: {:ok, {key, type}}
    end)
    |> case do
      {:ok, keys_and_types} ->
        {:ok, {:keyword, keys_and_types}}

      :error ->
        :error
    end
  end

  def resolve([quoted_item_spec]) do
    with {:ok, item_type} <- resolve(quoted_item_spec), do: {:ok, {:list, [item_type]}}
  end

  def resolve({:%{}, [], []}), do: {:ok, {:empty_map, []}}

  def resolve({:%{}, [], [_ | _] = quoted_map_contents}) do
    {quoted_required_kvs, quoted_optional_kvs} =
      Enum.reduce(quoted_map_contents, {[], []}, fn
        {{:required, [], [quoted_key_spec]}, quoted_value_spec}, {required, optional} ->
          {[{quoted_key_spec, quoted_value_spec} | required], optional}

        {{:optional, [], [quoted_key_spec]}, quoted_value_spec}, {required, optional} ->
          {required, [{quoted_key_spec, quoted_value_spec} | optional]}

        {quoted_key_spec, quoted_value_spec}, {required, optional}
        when is_atom(quoted_key_spec) ->
          {[{quoted_key_spec, quoted_value_spec} | required], optional}
      end)

    resolve_keys_and_values = &resolve_kvs(Enum.reverse(&1))

    with {:ok, required_kvs} <- resolve_keys_and_values.(quoted_required_kvs),
         {:ok, optional_kvs} <- resolve_keys_and_values.(quoted_optional_kvs) do
      {:ok, {:map, [required_kvs, optional_kvs]}}
    end
  end

  def resolve({:%, [], [aliases, {:%{}, [], quoted_required_kvs}]}) do
    with {:ok, kv_types} <- resolve_kvs(quoted_required_kvs) do
      module =
        case aliases do
          {:__aliases__, [alias: false], module_path} ->
            Module.concat(module_path)

          {:__aliases__, [alias: module], _} ->
            module
        end

      {:ok, {:struct, [module, kv_types]}}
    end
  end

  def resolve({:{}, [], quoted_elem_specs}) do
    with {:ok, elem_types} <- maybe_map(quoted_elem_specs, &resolve/1) do
      {:ok, {:tuple, elem_types}}
    end
  end

  def resolve({lhs_quoted_spec, rhs_quoted_spec}) do
    with {:ok, lhs_type} <- resolve(lhs_quoted_spec),
         {:ok, rhs_type} <- resolve(rhs_quoted_spec) do
      {:ok, {:tuple, [lhs_type, rhs_type]}}
    end
  end

  def resolve({{:., [], [{:__aliases__, aliases, module_path}, type_name]}, [], []}) do
    with {:ok, module} <- resolve_module(aliases, module_path) do
      resolve_compiled_remote_type(module, type_name)
    end
  end

  def resolve(other) do
    IO.inspect(other, label: "Failed to resolve")
    :error
  end

  defp resolve_compiled_remote_type(module, type_name) do
    with {:ok, compiled_type} <- fetch_compiled_type(module, type_name) do
      resolve_compiled_type(module, compiled_type)
    end
  end

  defp resolve_compiled_type(module, {_, {:user_type, _, type_name, _}, _}) do
    resolve_compiled_remote_type(module, type_name)
  end

  defp resolve_compiled_type(_module, type) do
    {:"::", _, [_, quoted_spec]} = Code.Typespec.type_to_quoted(type)
    resolve(quoted_spec)
  end

  defp fetch_compiled_type(module, type_name) do
    with {:ok, types} <- Code.Typespec.fetch_types(module) do
      Enum.find_value(types, :error, fn
        {:type, {^type_name, _, _} = compiled_type} ->
          {:ok, compiled_type}

        _other ->
          false
      end)
    end
  end

  defp resolve_module([alias: false], module_path) do
    {:ok, Module.concat(module_path)}
  end

  defp resolve_module([alias: module], _module_path) do
    {:ok, module}
  end

  @spec resolve_kvs([{quoted_spec(), quoted_spec()}]) :: result([{type(), type()}])
  defp resolve_kvs(quoted_kvs) do
    maybe_map(
      quoted_kvs,
      fn {quoted_key_spec, quoted_value_spec} ->
        with {:ok, key_type} <- resolve(quoted_key_spec),
             {:ok, value_type} <- resolve(quoted_value_spec) do
          {:ok, {key_type, value_type}}
        end
      end
    )
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
