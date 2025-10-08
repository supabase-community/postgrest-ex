defmodule Supabase.PostgREST.Parser do
  @moduledoc "simple parser for create statements on postgresql"

  @type ast :: list(table | rls_policy)

  @type table :: {table_name, columns :: list(column)}
  @type column :: {name :: String.t(), attrs :: list(column_def)}
  @type column_def ::
          {:type, String.t()}
          | {:primary, boolean}
          | {:null, boolean}
          | {:references, table_name}
          | {:default, String.t()}

  @type table_name :: {schema :: String.t(), name :: String.t()} | String.t()

  @type rls_policy :: {name :: String.t(), rls_config :: list(rls_option)}
  @type rls_option ::
          {:type, :permissive | :restricted}
          | {:on, table_name}
          | {:for, :all | :insert | :update | :delete | :select}
          | {:role, String.t()}
          | {:using, String.t()}
          | {:with_check, String.t()}

  @spec run(input :: binary) :: {:ok, ast} | {:error, atom}
  def run(input) when is_binary(input) do
    input = split_input(input)

    with {:ok, ast} <- parse(input, []) do
      reversed_ast = Enum.reverse(ast)
      {:ok, apply_primary_keys(reversed_ast)}
    end
  end

  def split_input(input) do
    input
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/\"/, "")
    |> String.split(~r"\s+|\,|\;|\(|\)", trim: true, include_captures: true)
    |> Enum.reject(&String.match?(&1, ~r/\s+/))
    |> Enum.map(&String.trim/1)
  end

  defp parse([], ast), do: {:ok, ast}

  defp parse(["create", "table" | rest], ast) do
    parse_table(rest, ast)
  end

  defp parse(["create", "policy" | rest], ast) do
    parse_policy(rest, ast)
  end

  defp parse(["alter", "table" | rest], ast) do
    parse_alter_table(rest, ast)
  end

  defp parse([_ | rest], ast), do: parse(rest, ast)

  defp parse_table(["if", "not", "exists" | rest], ast) do
    {rest, ast} = parse_table(rest, ast)
    parse(rest, ast)
  end

  defp parse_table([name, "(" | rest], ast) do
    table_name =
      case String.split(name, ".") do
        [name] -> name
        [schema, name] -> {schema, name}
      end

    {rest, cols} = parse_table_cols(rest)

    {rest, [{table_name, cols} | ast]}
  end

  defp parse_table_cols(rest) do
    {cols_tokens, rest} = Enum.split_while(rest, &(&1 != ";"))

    cols =
      cols_tokens
      |> split_by_comma()
      |> Enum.reject(&(&1 == []))
      |> Enum.map(&parse_column/1)
      |> Enum.reject(&is_nil/1)

    {rest, cols}
  end

  defp split_by_comma(tokens) do
    tokens
    |> Enum.chunk_by(&(&1 == ","))
    |> Enum.reject(&(&1 == [","]))
  end

  defp parse_column(["constraint" | _rest]), do: nil

  defp parse_column([name | attrs]) do
    {name, parse_column_attrs(attrs, [])}
  end

  defp parse_column_attrs([], acc), do: Enum.reverse(acc)

  defp parse_column_attrs(["not", "null" | rest], acc) do
    parse_column_attrs(rest, [{:null, false} | acc])
  end

  defp parse_column_attrs(["null" | rest], acc) do
    parse_column_attrs(rest, [{:null, true} | acc])
  end

  defp parse_column_attrs(["primary", "key" | rest], acc) do
    parse_column_attrs(rest, [{:primary, true} | acc])
  end

  defp parse_column_attrs(["default", value | rest], acc) do
    parse_column_attrs(rest, [{:default, value} | acc])
  end

  defp parse_column_attrs(["references", table | rest], acc) do
    parse_column_attrs(rest, [{:references, table} | acc])
  end

  defp parse_column_attrs([type | rest], acc)
       when type in ["character", "varchar", "text"] do
    parse_column_attrs(rest, [{:type, "string"} | acc])
  end

  defp parse_column_attrs([type | rest], acc) do
    case map_pg_type(type) do
      nil -> parse_column_attrs(rest, acc)
      ecto_type -> parse_column_attrs(rest, [{:type, ecto_type} | acc])
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp map_pg_type(type) do
    cond do
      int_type?(type) -> "integer"
      float_type?(type) -> "float"
      map_type?(type) -> "map"
      type == "interval" -> "duration"
      type == "timestamp" -> "naive_datetime"
      type == "timestampz" -> "utc_datetime"
      type == "timez" -> "time_usec"
      type == "uuid" -> "binary_id"
      type == "bytea" -> "binary"
      decimal_type?(type) -> "decimal"
      as_is_type?(type) -> type
      true -> nil
    end
  end

  defp int_type?(type) do
    type in ["integer", "bigint", "smallint", "serial", "bigserial"]
  end

  defp as_is_type?(type), do: type in ["boolean", "date", "time"]
  defp decimal_type?(type), do: type in ["numeric", "decimal"]
  defp float_type?(type), do: type in ["real", "numeric"]
  defp map_type?(type), do: type in ["json", "jsonb"]

  defp parse_policy([name | rest], ast) do
    {rest, opts} = parse_policy_opts(rest, [])
    parse(rest, [{name, opts} | ast])
  end

  defp parse_policy_opts(["on" | rest], acc) do
    {table, rest} = parse_table_name(rest)
    parse_policy_opts(rest, [{:on, table} | acc])
  end

  defp parse_policy_opts(["as", type | rest], acc) when type in ["permissive", "restrictive"] do
    type_atom = if type == "permissive", do: :permissive, else: :restrictive
    parse_policy_opts(rest, [{:type, type_atom} | acc])
  end

  defp parse_policy_opts(["for", action | rest], acc)
       when action in ["all", "select", "insert", "update", "delete"] do
    parse_policy_opts(rest, [{:for, String.to_atom(action)} | acc])
  end

  defp parse_policy_opts(["to", role | rest], acc) do
    parse_policy_opts(rest, [{:role, role} | acc])
  end

  defp parse_policy_opts(["using", "(" | rest], acc) do
    {expr, rest} = parse_expression(rest, [])
    parse_policy_opts(rest, [{:using, expr} | acc])
  end

  defp parse_policy_opts(["with", "check", "(" | rest], acc) do
    {expr, rest} = parse_expression(rest, [])
    parse_policy_opts(rest, [{:with_check, expr} | acc])
  end

  defp parse_policy_opts([";" | rest], acc) do
    {rest, Enum.reverse(acc)}
  end

  defp parse_policy_opts([_ | rest], acc) do
    parse_policy_opts(rest, acc)
  end

  defp parse_policy_opts([], acc), do: {[], Enum.reverse(acc)}

  defp parse_table_name([name | rest]) do
    table_name =
      case String.split(name, ".") do
        [name] -> name
        [schema, name] -> {schema, name}
      end

    {table_name, rest}
  end

  defp parse_expression([")" | rest], acc) do
    {Enum.reverse(acc) |> Enum.join(" "), rest}
  end

  defp parse_expression([token | rest], acc) do
    parse_expression(rest, [token | acc])
  end

  # Parse ALTER TABLE statements for PRIMARY KEY constraints
  defp parse_alter_table(["only" | rest], ast) do
    parse_alter_table(rest, ast)
  end

  defp parse_alter_table([table_name | rest], ast) do
    case rest do
      ["add", "constraint", _name, "primary", "key", "(" | rest] ->
        {column, rest} = extract_column_name(rest)
        table = parse_table_identifier(table_name)
        parse(rest, [{:pk, table, column} | ast])

      _ ->
        skip_to_semicolon(rest, ast)
    end
  end

  defp parse_table_identifier(name) do
    case String.split(name, ".") do
      [name] -> name
      [schema, name] -> {schema, name}
    end
  end

  defp extract_column_name([")" | rest]), do: {nil, rest}
  defp extract_column_name([col, ")" | rest]), do: {col, rest}
  defp extract_column_name([_col | rest]), do: extract_column_name(rest)

  defp skip_to_semicolon([";" | rest], ast), do: parse(rest, ast)
  defp skip_to_semicolon([_ | rest], ast), do: skip_to_semicolon(rest, ast)
  defp skip_to_semicolon([], ast), do: parse([], ast)

  # Apply primary key constraints to tables
  defp apply_primary_keys(ast) do
    ast
    |> Enum.reduce([], &inject_primary_keys/2)
    |> Enum.reverse()
  end

  defp inject_primary_keys({:pk, table, column}, acc) do
    Enum.map(acc, &update_table_primary_key(&1, table, column))
  end

  defp inject_primary_keys(item, acc), do: [item | acc]

  defp update_table_primary_key({table, columns}, table, column) when is_list(columns) do
    {table, mark_column_as_primary(columns, column)}
  end

  defp update_table_primary_key(other, _table, _column), do: other

  defp mark_column_as_primary(columns, primary_column) do
    Enum.map(columns, fn
      {^primary_column, attrs} -> {primary_column, [{:primary, true} | attrs]}
      other -> other
    end)
  end
end
