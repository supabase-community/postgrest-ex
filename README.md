# Supabase PostgREST

The `Supabase.PostgREST` module provides a suite of functions to interact with a Supabase PostgREST API using a fluent interface. This allows you to construct and execute complex queries in the context of a Supabase database application, facilitating a more functional approach to managing database operations in Elixir.

Please, refers to the [official Supabase PostgREST](https://supabase.com/docs/guides/api) documentation to have the context on how to apply query and filters on your data, and also configure your project to expose the PostgREST API.

## Installation

Add the following dependencies to your `mix.exs` file:

```elixir
def deps do
  [
    {:supabase_potion, "~> 0.4"},
    {:supabase_postgrest, "~> 0.1"}
  ]
end
```

Then, run `mix deps.get` to fetch the dependencies.

## Usage

### Initializing the Client

Before using the `Supabase.PostgREST` module, you need to initialize a Supabase client. This client handles the authentication and configuration needed to interact with the Supabase services.

You can initialize the client as follows:

```elixir
iex> {:ok, client} = Supabase.init_client(%{conn: %{base_url: "<supa-url>", api_key: "<supa-key>"}})
```

> Refer to the [base SDK documentation](https://hexdocs.pm/supabase_potion/0.4.1/readme.html#starting-a-client) for more details about client initialization

This client struct is passed to the various `Supabase.PostgREST` functions to perform operations on your Supabase database.

### Basic Operations

Here’s how you can perform common operations using the `Supabase.PostgREST` module.

Note that all operations and filters on `Supabase.PostgREST` are **lazy**, that means that queries, insertions, deletions and updates are only executed when you explicit call `Supabase.PostgREST.execute/1`.

#### Selecting Data

To select records from a table, use the `from/2` and `select/3` functions:

```elixir
iex> alias Supabase.PostgREST, as: Q
iex> Q.from(client, "users") |> Q.select("*", returning: true) |> Q.execute()
iex> {:ok, result} | {:error, %Supabase.PostgREST.Error{}}
```

You can specify the columns to retrieve instead of using `*`:

```elixir
iex> Q.select(query, ["id", "name"], returning: true)
```

#### Inserting Data

To insert new records, use the `insert/3` function:

```elixir
iex> alias Supabase.PostgREST, as: Q
iex> Q.from(client, "users") |> Q.insert(%{name: "John Doe", age: 30}, returning: :representation) |> Q.execute()
iex> {:ok, result} | {:error, %Supabase.PostgREST.Error{}}
```

#### Updating Data

To update existing records, use the `update/3` function:

```elixir
iex> alias Supabase.PostgREST, as: Q
iex> Q.from(client, "users") |> Q.eq("id", 1) |> Q.update(%{name: "John Smith"}, returning: :representation) |> Q.execute()
iex> {:ok, result} | {:error, %Supabase.PostgREST.Error{}}
```

#### Deleting Data

To delete records, use the `delete/2` function:

```elixir
iex> alias Supabase.PostgREST, as: Q
iex> Q.from(client, "users") |> Q.eq("id", 1) |> Q.delete(query, returning: :representation) |> Q.execute()
iex> {:ok, result} | {:error, %Supabase.PostgREST.Error{}}
```

### Filtering Data

You can apply various filters to your queries using functions like `eq/3`, `lt/3`, `gt/3`, etc.

```elixir
iex> alias Supabase.PostgREST, as: Q
iex> Q.from(client, "users") |> Q.eq("status", "active") |> Q.select("*", returning: true) |> Q.execute()
iex> {:ok, result} | {:error, %Supabase.PostgREST.Error{}}
```

### Advanced Query Building

You can also perform more advanced operations like full-text search, ordering, limiting, and combining filters using logical operators:

```elixir
iex> alias Supabase.PostgREST, as: Q
iex> Q.from(client, "users")
     |> Q.text_search("name", "John", type: :plain)
     |> Q.order("created_at", asc: true)
     |> Q.select(["id", "name", "created_at"], returning: true)
     |> Q.execute()
iex> {:ok, result} | {:error, %Supabase.PostgREST.Error{}}
```

### Executing Queries

After constructing a query, you can execute it using the `execute/1` or `execute_to/2` functions. The `execute_to/2` function allows you to map the results directly to a specific schema:

```elixir
iex> defmodule User, do: defstruct([:id])
iex> alias Supabase.PostgREST, as: Q
iex> Q.from(client, "users")
     |> Q.eq("id", 1)
     |> Q.select(["id"], returning: true)
     |> Q.execute_to(User)
iex> {:ok, %User{} = user} | {:error, %Supabase.PostgREST.Error{}}
```

## Contributing

If you find any issues or have suggestions for improvements, please feel free to open an issue or a pull request on the GitHub repository.

## License

This project is licensed under the MIT License.

---

This README provides a clear and structured guide for users of your package, with accurate examples and explanations of how to use the various functions provided by the `Supabase.PostgREST` module.
