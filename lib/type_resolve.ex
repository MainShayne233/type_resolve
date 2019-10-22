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

  defmodule Context do
    @type type :: {atom(), [term()]}
    @type quoted_spec :: Macro.t()
    @type t :: %__MODULE__{
            module: atom() | nil,
            bindings: [{quoted_spec(), type()}],
            type_path: list()
          }
    defstruct([:module, bindings: [], type_path: []])
  end

  @spec __basic_types__ :: %{required(type_name) => quoted_spec()}
  def __basic_types__, do: @basic_types

  @spec __built_in_types__ :: %{required(type_name) => quoted_spec()}
  def __built_in_types__, do: @built_in_types

  @spec from_quoted_type(quoted_spec(), Context.t()) :: result(type())
  def from_quoted_type(quoted_spec, context \\ %Context{})

  for {type, {quoted_spec_name, _, _params}} <- Map.merge(@basic_types, @built_in_types) do
    def from_quoted_type({unquote(quoted_spec_name), _, params}, context) do
      with {:ok, resolved_params} <- maybe_map(params, &from_quoted_type(&1, context)) do
        {:ok, {unquote(type), resolved_params}}
      end
    end
  end

  defguardp is_literal(value) when is_atom(value) or is_integer(value)

  def from_quoted_type(literal, _context) when is_literal(literal),
    do: {:ok, {:literal, [literal]}}

  def from_quoted_type({:.., _, [min, max]}, _context) when is_integer(min) and is_integer(max) do
    {:ok, {:literal, [min..max]}}
  end

  def from_quoted_type({:<<>>, [], args}, _context) do
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

  def from_quoted_type([{:->, _, [[{:..., _, _}], return_spec]}], context) do
    with {:ok, return_type} <- from_quoted_type(return_spec, context) do
      {:ok, {:function, [{:any, return_type}]}}
    end
  end

  def from_quoted_type([{:->, _, [param_specs, return_spec]}], context) do
    with {:ok, param_types} <- maybe_map(param_specs, &from_quoted_type(&1, context)),
         {:ok, return_type} <- from_quoted_type(return_spec, context) do
      {:ok, {:function, [{param_types, return_type}]}}
    end
  end

  def from_quoted_type([quoted_item_spec, {:..., _, _}], context) do
    with {:ok, item_type} <- from_quoted_type(quoted_item_spec, context),
         do: {:ok, {:non_empty_list, [item_type]}}
  end

  def from_quoted_type([{:..., _, _}], _context), do: {:ok, {:non_empty_list, [{:any, []}]}}

  def from_quoted_type([], _context), do: {:ok, {:empty_list, []}}

  def from_quoted_type([:...], _context), do: {:ok, {:empty_list, []}}

  def from_quoted_type([{key, _quoted_item_spec} | _] = quoted_keyword_spec, context)
      when is_atom(key) do
    quoted_keyword_spec
    |> maybe_map(fn {key, quoted_spec} ->
      with {:ok, type} <- from_quoted_type(quoted_spec, context), do: {:ok, {key, type}}
    end)
    |> case do
      {:ok, keys_and_types} ->
        {:ok, {:keyword, keys_and_types}}

      :error ->
        :error
    end
  end

  def from_quoted_type([quoted_item_spec], context) do
    with {:ok, item_type} <- from_quoted_type(quoted_item_spec, context),
         do: {:ok, {:list, [item_type]}}
  end

  def from_quoted_type({:%{}, [], []}, _context), do: {:ok, {:empty_map, []}}

  def from_quoted_type({:%{}, [], [_ | _] = quoted_map_contents}, context) do
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

    resolve_keys_and_values = &resolve_kvs(Enum.reverse(&1), context)

    with {:ok, required_kvs} <- resolve_keys_and_values.(quoted_required_kvs),
         {:ok, optional_kvs} <- resolve_keys_and_values.(quoted_optional_kvs) do
      {:ok, {:map, [required_kvs, optional_kvs]}}
    end
  end

  def from_quoted_type({:%, [], [aliases, {:%{}, [], quoted_required_kvs}]}, context) do
    with {:ok, kv_types} <- resolve_kvs(quoted_required_kvs, context) do
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

  def from_quoted_type({:{}, _, quoted_elem_specs}, context) do
    with {:ok, elem_types} <- maybe_map(quoted_elem_specs, &from_quoted_type(&1, context)) do
      {:ok, {:tuple, elem_types}}
    end
  end

  def from_quoted_type({lhs_quoted_spec, rhs_quoted_spec}, context) do
    with {:ok, lhs_type} <- from_quoted_type(lhs_quoted_spec, context),
         {:ok, rhs_type} <- from_quoted_type(rhs_quoted_spec, context) do
      {:ok, {:tuple, [lhs_type, rhs_type]}}
    end
  end

  def from_quoted_type({{:., _, module_info}, _, quoted_args}, context) do
    with {:ok, {module, type_name}} <- resolve_remote_module_and_type_name(module_info),
         {:ok, type_args} <- maybe_map(quoted_args, &from_quoted_type(&1, context)) do
      resolve_compiled_remote_type(module, type_name, type_args)
    end
  end

  def from_quoted_type({:|, _, _} = quoted_union_type, context) do
    with {:ok, types} <- resolve_union_types(quoted_union_type, context) do
      {:ok, {:union, types}}
    end
  end

  def from_quoted_type(quoted_spec, context) do
    with :error <- resolve_type_from_binding(quoted_spec, context),
         :error <- resolve_type_from_context_module(quoted_spec, context) do
      IO.inspect({quoted_spec, context}, label: "Failed to resolve")
      :error
    end
  end

  defp resolve_type_from_binding(quoted_spec, context) do
    Enum.find_value(context.bindings, :error, fn
      {^quoted_spec, arg_type} ->
        {:ok, arg_type}

      _other ->
        false
    end)
  end

  defp resolve_type_from_context_module(quoted_spec, context) do
    with {type_name, _, _} <- quoted_spec,
         module when is_atom(module) <- context.module do
      resolve_compiled_remote_type(module, type_name, [])
    end
  end

  defp resolve_union_types(quoted_union_types, context, types \\ [])

  defp resolve_union_types({:|, _, [quoted_spec, rest]}, context, types) do
    with {:ok, type} <- from_quoted_type(quoted_spec, context) do
      resolve_union_types(rest, context, [type | types])
    end
  end

  defp resolve_union_types(quoted_spec, context, types) do
    with {:ok, type} <- from_quoted_type(quoted_spec, context) do
      {:ok, Enum.reverse([type | types])}
    end
  end

  defp resolve_compiled_remote_type(module, type_name, type_args) do
    with {:ok, compiled_type} <- fetch_compiled_type(module, type_name, type_args) do
      resolve_compiled_type(module, compiled_type, type_args)
    end
  end

  defp resolve_compiled_type(module, {_, {:user_type, _, type_name, _}, _}, type_args) do
    resolve_compiled_remote_type(module, type_name, type_args)
  end

  defp resolve_compiled_type(module, type, type_args) do
    {:"::", _, [{_, [], params}, quoted_spec]} = Code.Typespec.type_to_quoted(type)
    from_quoted_type(quoted_spec, %Context{module: module, bindings: Enum.zip(params, type_args)})
  end

  defp fetch_compiled_type(module, type_name, type_args) do
    with {:ok, types} <- Code.Typespec.fetch_types(module) do
      Enum.find_value(types, :error, fn
        {_, {^type_name, _, type_params} = compiled_type}
        when length(type_params) == length(type_args) ->
          {:ok, compiled_type}

        _other ->
          false
      end)
    end
  end

  defp resolve_remote_module_and_type_name([
         {:__aliases__, [counter: {module_prefix, _}], [{_, _, _}, module_part]},
         type_name
       ]) do
    {:ok, {Module.concat([module_prefix, module_part]), type_name}}
  end

  defp resolve_remote_module_and_type_name([
         {:__aliases__, [alias: false], module_path},
         type_name
       ]) do
    {:ok, {Module.concat(module_path), type_name}}
  end

  defp resolve_remote_module_and_type_name([{:__aliases__, [alias: module], _}, type_name])
       when is_atom(module) do
    {:ok, {module, type_name}}
  end

  defp resolve_remote_module_and_type_name([module, type_name]) when is_atom(module) do
    {:ok, {module, type_name}}
  end

  @spec resolve_kvs([{quoted_spec(), quoted_spec()}], Context.t()) :: result([{type(), type()}])
  defp resolve_kvs(quoted_kvs, context) do
    maybe_map(
      quoted_kvs,
      fn {quoted_key_spec, quoted_value_spec} ->
        with {:ok, key_type} <- from_quoted_type(quoted_key_spec, context),
             {:ok, value_type} <- from_quoted_type(quoted_value_spec, context) do
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
