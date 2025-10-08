defmodule Mix.Tasks.Supabase.Gen.Schema do
  @shortdoc "Generates Ecto schemas from Supabase database"

  @moduledoc """
  Generates Ecto schemas from Supabase database DDL.

      $ mix supabase.gen.schema Context [options]

  This task connects to your Supabase database using the Supabase CLI,
  dumps the schema, and generates corresponding Ecto schema modules organized
  by context.

  The first argument is the context module name (e.g., `Accounts`, `Blog`),
  which determines both the module namespace and output directory. All remaining
  arguments are passed directly to `supabase db dump`.

  ## Examples

  Generate schemas for Accounts context from auth schema:

      $ mix supabase.gen.schema Accounts -s auth

  Generate from local Supabase instance:

      $ mix supabase.gen.schema Blog --local

  Generate specific schema with data-only:

      $ mix supabase.gen.schema Content --schema public --data-only

  Multiple schemas:

      $ mix supabase.gen.schema Admin --schema auth,public

  ## Output Structure

  Schemas are generated in the context directory:

      lib/my_app/accounts/
        ├── user.ex        # MyApp.Accounts.User
        └── profile.ex     # MyApp.Accounts.Profile

  ## Prerequisites

  This task requires the Supabase CLI to be installed and available in your PATH.
  You can install it by following the instructions at:
  https://supabase.com/docs/guides/cli

  For remote projects, make sure you're linked to your Supabase project:

      $ supabase link --project-ref <your-project-ref>

  ## Generated Schema Structure

  Each table generates an Ecto schema module:

      defmodule MyApp.Accounts.User do
        @moduledoc \"\"\"
        Ecto schema for users table.

        ## RLS Policies
        - **Users can view own data** (SELECT): `auth.uid() = id`
        - **Users can update own profile** (UPDATE): `auth.uid() = id`
        \"\"\"

        use Ecto.Schema
        import Ecto.Changeset

        @primary_key {:id, :binary_id, autogenerate: true}

        schema "users" do
          field :email, :string
          field :name, :string

          timestamps(type: :utc_datetime)
        end

        @doc false
        def changeset(user, attrs) do
          user
          |> cast(attrs, [:email, :name])
          |> validate_required([:email])
          |> unique_constraint(:email)
        end
      end

  ## Type Mapping

  PostgreSQL types are automatically mapped to Ecto types:

    * `text`, `varchar`, `char` -> `:string`
    * `integer`, `bigint`, `smallint` -> `:integer`
    * `uuid` -> `:binary_id` (mapped to `Ecto.UUID`)
    * `boolean` -> `:boolean`
    * `timestamp with time zone`, `timestamptz` -> `:utc_datetime`
    * `timestamp` -> `:naive_datetime`
    * `date` -> `:date`
    * `time`, `timez` -> `:time_usec`
    * `json`, `jsonb` -> `:map`
    * `numeric`, `decimal` -> `:decimal`
    * `real`, `double precision` -> `:float`
    * `bytea` -> `:binary`

  ## RLS Policies

  RLS (Row Level Security) policies are automatically extracted from your database
  and included in the schema module documentation. This helps document which
  security policies are enforced at the database level.

  Note: RLS policies are enforced by PostgreSQL, not by Ecto. The generated
  documentation serves as a reference for developers.

  ## Supabase CLI Arguments

  All arguments after the context name are passed directly to `supabase db dump`.
  Common options include:

    * `--local` - Use local Supabase instance
    * `--schema <name>` - Specify schema(s) to dump (comma-separated)
    * `--data-only` - Dump only data, not schema
    * `--db-url <url>` - Custom database URL
    * `--password <pass>` - Database password

  See `supabase db dump --help` for all available options.
  """

  use Mix.Task

  alias Supabase.PostgREST.Parser

  @impl Mix.Task
  def run([]) do
    Mix.raise("""
    mix supabase.gen.schema requires a context name.

    For example:

        mix supabase.gen.schema Accounts
        mix supabase.gen.schema Blog --local
        mix supabase.gen.schema Content -s public

    See `mix help supabase.gen.schema` for more information.
    """)
  end

  def run([context | cli_args]) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix supabase.gen.schema can only be run inside an application directory")
    end

    config = build_config(context)

    Mix.shell().info("Connecting to Supabase...")

    with {:ok, ddl} <- dump_schema(cli_args),
         {:ok, ast} <- parse_ddl(ddl),
         :ok <- validate_ast(ast) do
      generate_schemas(ast, config)
    else
      {:error, :supabase_not_found} ->
        Mix.raise("""
        The Supabase CLI was not found in your PATH.

        Please install the Supabase CLI to use this task:
        https://supabase.com/docs/guides/cli

        On macOS, you can install it with Homebrew:
            brew install supabase/tap/supabase

        On Linux, you can use the install script:
            curl -sL https://cli.supabase.io/install.sh | bash
        """)

      {:error, :not_linked} ->
        Mix.raise("""
        Your project is not linked to a Supabase project.

        To use a remote Supabase project, link your project first:
            supabase link --project-ref <your-project-ref>

        Alternatively, use the --local flag to connect to a local instance:
            mix supabase.gen.schema #{context} --local
        """)

      {:error, :connection_failed, message} ->
        Mix.raise("""
        Failed to connect to Supabase database.

        #{String.trim(message)}

        Please verify:
        - Your database is running (for local instances)
        - Your project is linked correctly (for remote instances)
        - You have the necessary permissions
        """)

      {:error, :no_tables} ->
        Mix.raise("""
        No tables found in the database dump.

        Please verify:
        - Tables exist in your database
        - You have permission to access the schema
        - The correct schema is specified (use -s or --schema flag)

        Example:
            mix supabase.gen.schema #{context} -s public
        """)

      {:error, :parse_failed, reason} ->
        Mix.raise("""
        Failed to parse database schema.

        #{reason}

        This might be due to:
        - Unsupported DDL syntax
        - Complex table definitions

        Please report this issue with the DDL output at:
        https://github.com/supabase-community/postgrest-ex/issues
        """)

      {:error, message} when is_binary(message) ->
        Mix.raise("""
        Error: #{String.trim(message)}

        Run `supabase db dump --help` to see available options.
        """)
    end
  end

  defp build_config(context) do
    app_name = Mix.Project.config() |> Keyword.fetch!(:app)

    context_module = Module.concat([Macro.camelize(context)])
    base_module = Module.concat([Macro.camelize(to_string(app_name))])
    full_module = Module.concat([base_module, context_module])

    context_path = Macro.underscore(context)
    output_dir = Path.join(["lib", to_string(app_name), context_path])

    %{
      app_name: app_name,
      context: context,
      base_module: full_module,
      output_dir: output_dir
    }
  end

  defp dump_schema(cli_args) do
    case System.find_executable("supabase") do
      nil ->
        {:error, :supabase_not_found}

      executable ->
        args = ["db", "dump" | cli_args]
        Mix.shell().info("Running: supabase #{Enum.join(args, " ")}")
        Mix.shell().info("Dumping schema from Supabase...")

        case System.cmd(executable, args, stderr_to_stdout: true) do
          {output, 0} ->
            {:ok, output}

          {error_output, _exit_code} ->
            cond do
              String.contains?(error_output, "not linked") ->
                {:error, :not_linked}

              String.contains?(error_output, "connection") or
                String.contains?(error_output, "connect") or
                  String.contains?(error_output, "refused") ->
                {:error, :connection_failed, error_output}

              true ->
                {:error, error_output}
            end
        end
    end
  end

  defp parse_ddl(ddl) do
    Mix.shell().info("Parsing DDL...")

    case Parser.run(ddl) do
      {:ok, ast} -> {:ok, ast}
      {:error, reason} -> {:error, :parse_failed, inspect(reason)}
    end
  end

  defp validate_ast(ast) do
    tables =
      Enum.filter(ast, fn
        {_name, columns} when is_list(columns) -> true
        _ -> false
      end)

    if Enum.empty?(tables) do
      {:error, :no_tables}
    else
      :ok
    end
  end

  defp generate_schemas(ast, config) do
    tables = extract_tables(ast)
    policies = extract_policies(ast)

    Mix.shell().info("Generating #{length(tables)} schema(s)...")
    File.mkdir_p!(config.output_dir)

    for table <- tables do
      table_policies = filter_policies_for_table(policies, table)
      generate_schema_file(table, table_policies, config)
    end

    print_summary(tables, config)
  end

  defp extract_tables(ast) do
    Enum.filter(ast, fn
      {_name, columns} when is_list(columns) -> true
      _ -> false
    end)
  end

  defp extract_policies(ast) do
    Enum.filter(ast, fn
      {_name, opts} when is_list(opts) ->
        Keyword.has_key?(opts, :on) or Keyword.has_key?(opts, :for)

      _ ->
        false
    end)
  end

  defp filter_policies_for_table(policies, {table_name, _columns}) do
    target_name = normalize_table_name(table_name)

    Enum.filter(policies, fn {_policy_name, opts} ->
      case Keyword.get(opts, :on) do
        ^target_name -> true
        {_schema, ^target_name} -> true
        _ -> false
      end
    end)
  end

  defp normalize_table_name({_schema, name}), do: name
  defp normalize_table_name(name), do: name

  defp generate_schema_file({table_name, columns}, policies, config) do
    module_name = build_module_name(table_name, config)
    schema_name = normalize_table_name(table_name)
    file_path = build_file_path(schema_name, config)

    content = generate_schema_content(module_name, schema_name, columns, policies)

    File.write!(file_path, content)
    Mix.shell().info([:green, "* creating ", :reset, Path.relative_to_cwd(file_path)])
  end

  defp build_module_name(table_name, config) do
    schema_name = normalize_table_name(table_name)
    # Singularize and camelize the table name
    module_name =
      schema_name
      |> String.trim_trailing("s")
      |> Macro.camelize()

    Module.concat([config.base_module, module_name])
  end

  defp build_file_path(schema_name, config) do
    # Singularize the filename
    filename =
      schema_name
      |> String.trim_trailing("s")
      |> Macro.underscore()
      |> then(&"#{&1}.ex")

    Path.join(config.output_dir, filename)
  end

  defp generate_schema_content(module_name, schema_name, columns, policies) do
    primary_key = find_primary_key(columns)

    # Exclude primary key from regular fields
    regular_fields =
      if primary_key do
        columns -- [primary_key]
      else
        columns
      end

    # Get the base name for the changeset parameter
    base_name =
      module_name
      |> Module.split()
      |> List.last()
      |> Macro.underscore()

    """
    defmodule #{inspect(module_name)} do
      @moduledoc \"\"\"
      Ecto schema for #{schema_name} table.
    #{generate_rls_docs(policies)}
      \"\"\"

      use Ecto.Schema
      import Ecto.Changeset

    #{generate_primary_key_config(primary_key)}
      schema "#{schema_name}" do
    #{generate_fields(regular_fields)}
      end

      @doc false
      def changeset(#{base_name}, attrs) do
        #{base_name}
        |> cast(attrs, [#{generate_cast_fields(regular_fields)}])
        |> validate_required([#{generate_required_fields(regular_fields)}])
    #{generate_unique_constraints(regular_fields)}
      end
    end
    """
  end

  defp generate_rls_docs([]), do: ""

  defp generate_rls_docs(policies) do
    """

      ## RLS Policies
    #{Enum.map_join(policies, "\n", &format_policy/1)}
    """
  end

  defp format_policy({name, opts}) do
    action = opts |> Keyword.get(:for, :all) |> to_string() |> String.upcase()
    using = Keyword.get(opts, :using, "")
    "  - **#{name}** (#{action}): `#{using}`"
  end

  defp find_primary_key(columns) do
    Enum.find(columns, fn {_name, attrs} ->
      Keyword.get(attrs, :primary, false)
    end)
  end

  defp generate_primary_key_config(nil), do: ""

  defp generate_primary_key_config({name, attrs}) do
    type = Keyword.get(attrs, :type, "integer")

    case type do
      "binary_id" ->
        """
          @primary_key {:#{name}, :binary_id, autogenerate: true}
        """

      _ ->
        ""
    end
  end

  defp generate_fields([]), do: ""

  defp generate_fields(columns) do
    columns
    |> Enum.map(&format_field/1)
    |> Enum.join("\n")
  end

  defp format_field({name, attrs}) do
    type = Keyword.get(attrs, :type, "string")
    "    field :#{name}, #{format_ecto_type(type)}"
  end

  defp generate_cast_fields(columns) do
    columns
    |> Enum.map(fn {name, _attrs} -> ":#{name}" end)
    |> Enum.join(", ")
  end

  defp generate_required_fields(columns) do
    columns
    |> Enum.reject(fn {_name, attrs} -> Keyword.get(attrs, :null, true) end)
    |> Enum.map(fn {name, _attrs} -> ":#{name}" end)
    |> Enum.join(", ")
  end

  defp generate_unique_constraints(columns) do
    constraints =
      columns
      |> Enum.filter(fn {name, _attrs} ->
        name in ["email", "username", "slug"]
      end)
      |> Enum.map(fn {name, _attrs} ->
        "    |> unique_constraint(:#{name})"
      end)

    case constraints do
      [] -> ""
      list -> "\n" <> Enum.join(list, "\n")
    end
  end

  defp format_ecto_type("binary_id"), do: "Ecto.UUID"
  defp format_ecto_type(type), do: ":#{type}"

  defp print_summary(tables, config) do
    Mix.shell().info("")

    Mix.shell().info([
      :green,
      "✓ ",
      :reset,
      "Generated #{length(tables)} schema(s) in #{config.output_dir}"
    ])

    Mix.shell().info("""

    Next steps:

    1. Review the generated schemas in #{config.output_dir}
    2. Add any missing associations (has_many, belongs_to, etc.)
    3. Customize changeset validations as needed
    4. Create context functions to work with these schemas

    Generated schemas:
    #{Enum.map_join(tables, "\n", fn {name, _} -> "  - #{inspect(config.base_module)}.#{name |> normalize_table_name() |> String.trim_trailing("s") |> Macro.camelize()}" end)}
    """)
  end
end
