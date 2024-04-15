# Supabase PostgREST

[PostgREST](https://postgrest.org/en/v12/) implementation for the `supabase_potion` SDK in Elixir.

## Installation

```elixir
def deps do
  [
    {:supabase_potion, "~> 0.3"},
    {:supabase_postgrest, "~> 0.1"}
  ]
end
```

## Usage

Firstly you need to initialize your Supabase client(s) as can be found on the [supabase_potion documentation](https://hexdocs.pm/supabase_potion/Supabase.html#module-starting-a-client):

```elixir
iex> Supabase.init_client(%{name: Conn, conn: %{base_url: "<supa-url>", api_key: "<supa-key>"}})
{:ok, #PID<>}
```

Now you can pass the Client to the `Supabase.PostgREST` functions as a `PID` or the name that was registered on the client initialization:

```elixir
iex> Supabase.Storage.list_buckets(pid | client_name)  
```
