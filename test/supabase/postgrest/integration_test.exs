defmodule Supabase.PostgREST.IntegrationTest do
  use ExUnit.Case, async: true

  import Supabase.PostgREST.Helpers

  alias Supabase.Fetcher.Request
  alias Supabase.PostgREST

  setup do
    client = Supabase.init_client!("http://example.com", "test-key")
    {:ok, %{client: client}}
  end

  describe "query building chains" do
    test "builds complex query with select, filters, and transforms", %{client: client} do
      result =
        client
        |> PostgREST.from("users")
        |> PostgREST.select(["id", "name", "email", "created_at"], returning: true)
        |> PostgREST.eq("status", "active")
        |> PostgREST.gte("age", 18)
        |> PostgREST.order("created_at", asc: false)
        |> PostgREST.limit(10)

      assert %Request{
               method: :get,
               query: query,
               headers: headers,
               url: url
             } = result

      assert {"select", "id,name,email,created_at"} in query
      assert {"status", "eq.active"} in query
      assert {"age", "gte.18"} in query
      assert {"limit", "10"} in query
      assert Enum.any?(query, fn {k, v} -> k == "order" and v =~ "created_at.desc" end)
      assert get_header(headers, "prefer") == "count=exact"
      assert url.path =~ "users"
    end

    test "builds insert with returning specific columns", %{client: client} do
      data = %{name: "John Doe", email: "john@example.com", age: 25}

      result =
        client
        |> PostgREST.from("users")
        |> PostgREST.insert(data)
        |> PostgREST.returning(["id", "name", "created_at"])

      assert %Request{
               method: :post,
               body: body,
               query: query,
               headers: headers
             } = result

      # Body is encoded as iodata
      assert is_list(body)

      assert {"select", "id,name,created_at"} in query
      assert get_header(headers, "prefer") =~ "return=representation"
    end

    test "builds update with filters and transforms", %{client: client} do
      update_data = %{status: "inactive", updated_at: "2024-01-01T00:00:00Z"}

      result =
        client
        |> PostgREST.from("users")
        |> PostgREST.update(update_data)
        |> PostgREST.eq("status", "pending")
        |> PostgREST.lt("created_at", "2023-01-01")
        |> PostgREST.returning()

      assert %Request{
               method: :patch,
               body: body,
               query: query
             } = result

      # Body is encoded as iodata
      assert is_list(body)

      assert {"status", "eq.pending"} in query
      assert {"created_at", "lt.2023-01-01"} in query
      assert {"select", "*"} in query
    end

    test "builds delete with complex filters", %{client: client} do
      result =
        client
        |> PostgREST.from("posts")
        |> PostgREST.delete()
        |> PostgREST.eq("author_id", 123)
        |> PostgREST.within("status", ["draft", "rejected"])
        |> PostgREST.returning(["id"])

      assert %Request{
               method: :delete,
               query: query
             } = result

      assert {"author_id", "eq.123"} in query
      assert {"status", "in.(draft,rejected)"} in query
      assert {"select", "id"} in query
    end
  end

  describe "transform operation chains" do
    test "chains multiple order operations", %{client: client} do
      result =
        client
        |> PostgREST.from("products")
        |> PostgREST.select("*", returning: true)
        |> PostgREST.order("category", asc: true)
        |> PostgREST.order("price", asc: false)
        |> PostgREST.order("name", asc: true)

      assert %Request{query: query} = result
      order_values = for {k, v} <- query, k == "order", do: v
      assert "category.asc.nullslast,price.desc.nullslast,name.asc.nullslast" in order_values
    end

    test "combines range with limit", %{client: client} do
      result =
        client
        |> PostgREST.from("logs")
        |> PostgREST.select("*", returning: true)
        |> PostgREST.range(100, 199)
        |> PostgREST.limit(50)

      assert %Request{query: query} = result
      # range sets offset=100 and limit=100 (199-100+1)
      # then limit overrides to 50
      assert {"offset", "100"} in query
      assert {"limit", "50"} in query
    end

    test "chains filter, order, and output format", %{client: client} do
      result =
        client
        |> PostgREST.from("events")
        |> PostgREST.select(["id", "name", "location", "date"], returning: true)
        |> PostgREST.gte("date", "2024-01-01")
        |> PostgREST.order("date", asc: true)
        |> PostgREST.csv()

      assert %Request{headers: headers} = result
      assert get_header(headers, "accept") == "text/csv"
    end

    test "builds query with explain plan", %{client: client} do
      result =
        client
        |> PostgREST.from("analytics")
        |> PostgREST.select("*", returning: true)
        |> PostgREST.eq("user_id", 42)
        |> PostgREST.explain(analyze: true, verbose: true, format: :json)

      assert %Request{headers: headers} = result
      assert get_header(headers, "accept") =~ "application/vnd.pgrst.plan+json"
      assert get_header(headers, "accept") =~ "analyze"
      assert get_header(headers, "accept") =~ "verbose"
    end

    test "builds transaction with rollback", %{client: client} do
      result =
        client
        |> PostgREST.from("transactions")
        |> PostgREST.insert(%{amount: 100, type: "credit"})
        |> PostgREST.rollback()
        |> PostgREST.returning()

      assert %Request{headers: headers} = result
      assert get_header(headers, "prefer") =~ "tx=rollback"
      assert get_header(headers, "prefer") =~ "return=representation"
    end
  end

  describe "foreign table operations" do
    test "applies filters and transforms to foreign tables", %{client: client} do
      result =
        client
        |> PostgREST.from("authors")
        |> PostgREST.select(["id", "name", "posts(id,title,status)"], returning: true)
        |> PostgREST.order("name", asc: true)
        |> PostgREST.order("created_at", asc: false, foreign_table: "posts")
        |> PostgREST.limit(5, foreign_table: "posts")

      assert %Request{query: query} = result
      assert {"posts.order", "created_at.desc.nullslast"} in query
      assert {"posts.limit", "5"} in query
      assert Enum.any?(query, fn {k, v} -> k == "order" and v == "name.asc.nullslast" end)
    end

    test "applies range to foreign table", %{client: client} do
      result =
        client
        |> PostgREST.from("categories")
        |> PostgREST.select(["id", "name", "products(*)"], returning: true)
        |> PostgREST.range(0, 9, foreign_table: "products")

      assert %Request{query: query} = result
      assert {"products.offset", "0"} in query
      assert {"products.limit", "10"} in query
    end
  end

  describe "edge cases and special scenarios" do
    test "handles upsert with complex options", %{client: client} do
      data = %{id: 1, name: "Updated Name", version: 2}

      result =
        client
        |> PostgREST.from("documents")
        |> PostgREST.upsert(data, on_conflict: "id,version")
        |> PostgREST.returning(["id", "name", "version", "updated_at"])

      assert %Request{
               method: :post,
               headers: headers,
               query: query
             } = result

      assert get_header(headers, "prefer") =~ "resolution=merge-duplicates"
      assert get_header(headers, "prefer") =~ "on_conflict=id,version"
      assert {"select", "id,name,version,updated_at"} in query
    end

    test "builds query with single object expectation", %{client: client} do
      result =
        client
        |> PostgREST.from("config")
        |> PostgREST.select("*", returning: true)
        |> PostgREST.eq("key", "app_settings")
        |> PostgREST.single()

      assert %Request{headers: headers} = result
      assert get_header(headers, "accept") == "application/vnd.pgrst.object+json"
    end

    test "handles geojson output format", %{client: client} do
      result =
        client
        |> PostgREST.from("locations")
        |> PostgREST.select(["id", "name", "coordinates"], returning: true)
        |> PostgREST.within("city", ["New York", "Los Angeles"])
        |> PostgREST.geojson()

      assert %Request{headers: headers} = result
      assert get_header(headers, "accept") == "application/geo+json"
    end

    test "complex nested conditions with transforms", %{client: client} do
      result =
        client
        |> PostgREST.from("employees")
        |> PostgREST.select("*", returning: true)
        |> PostgREST.within("department", ["IT", "Engineering"])
        |> PostgREST.gte("salary", 50_000)
        |> PostgREST.neq("status", "terminated")
        |> PostgREST.order("salary", asc: false)
        |> PostgREST.limit(20)

      assert %Request{query: query} = result
      assert {"department", "in.(IT,Engineering)"} in query
      assert {"salary", "gte.50000"} in query
      assert {"status", "neq.terminated"} in query
    end
  end

  describe "method-specific behaviors" do
    test "maybe_single uses different media types based on method", %{client: client} do
      # GET request
      get_result =
        client
        |> PostgREST.from("settings")
        |> PostgREST.select("*", returning: true)
        |> PostgREST.maybe_single()

      assert %Request{headers: get_headers} = get_result
      assert get_header(get_headers, "accept") == "application/json"

      # POST request
      post_result =
        client
        |> PostgREST.from("settings")
        |> PostgREST.insert(%{key: "test", value: "123"})
        |> PostgREST.maybe_single()

      assert %Request{headers: post_headers} = post_result
      assert get_header(post_headers, "accept") == "application/vnd.pgrst.object+json"
    end
  end
end
