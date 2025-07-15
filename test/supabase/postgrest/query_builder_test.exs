defmodule Supabase.PostgREST.QueryBuilderTest do
  use ExUnit.Case, async: true

  import Supabase.PostgREST.Helpers

  alias Supabase.Fetcher.Request
  alias Supabase.PostgREST.QueryBuilder

  setup do
    client = Supabase.init_client!("http://example.com", "test-key")
    request = Request.new(client)
    {:ok, %{request: request}}
  end

  describe "select/3" do
    test "selects all columns with '*'", %{request: request} do
      result = QueryBuilder.select(request, "*")
      assert %Request{method: :head, query: query, headers: headers} = result
      assert {"select", "*"} in query
      assert get_header(headers, "prefer") == "count=exact"
    end

    test "selects specific columns from list", %{request: request} do
      result = QueryBuilder.select(request, ["id", "name", "email"])
      assert %Request{query: query} = result
      assert {"select", "id,name,email"} in query
    end

    test "sets method to GET when returning is true", %{request: request} do
      result = QueryBuilder.select(request, "*", returning: true)
      assert %Request{method: :get} = result
    end

    test "sets method to HEAD when returning is false", %{request: request} do
      result = QueryBuilder.select(request, "*", returning: false)
      assert %Request{method: :head} = result
    end

    test "sets count preference", %{request: request} do
      result = QueryBuilder.select(request, "*", count: :planned)
      assert %Request{headers: headers} = result
      assert get_header(headers, "prefer") == "count=planned"
    end

    test "handles empty column list", %{request: request} do
      result = QueryBuilder.select(request, [])
      assert %Request{query: query} = result
      assert {"select", ""} in query
    end

    test "defaults to exact count and no returning", %{request: request} do
      result = QueryBuilder.select(request, "*")
      assert %Request{method: :head, headers: headers} = result
      assert get_header(headers, "prefer") == "count=exact"
    end

    test "preserves column order in list", %{request: request} do
      columns = ["created_at", "id", "status", "name"]
      result = QueryBuilder.select(request, columns)
      assert %Request{query: query} = result
      assert {"select", "created_at,id,status,name"} in query
    end
  end

  describe "insert/3" do
    test "creates POST request with data", %{request: request} do
      data = %{name: "John Doe", email: "john@example.com"}
      result = QueryBuilder.insert(request, data)
      assert %Request{method: :post, body: body} = result
      # Body is encoded as iodata for HTTP transmission
      assert is_list(body)
    end

    test "sets default prefer headers", %{request: request} do
      result = QueryBuilder.insert(request, %{})
      assert %Request{headers: headers} = result
      assert get_header(headers, "prefer") == "return=representation,count=exact"
    end

    test "handles on_conflict option", %{request: request} do
      result = QueryBuilder.insert(request, %{}, on_conflict: "email")
      assert %Request{headers: headers, query: query} = result
      assert get_header(headers, "prefer") =~ "on_conflict=email"
      assert get_header(headers, "prefer") =~ "resolution=merge-duplicates"
      assert {"on_conflict", "email"} in query
    end

    test "sets returning preference", %{request: request} do
      result = QueryBuilder.insert(request, %{}, returning: :minimal)
      assert %Request{headers: headers} = result
      assert get_header(headers, "prefer") =~ "return=minimal"
    end

    test "sets count preference", %{request: request} do
      result = QueryBuilder.insert(request, %{}, count: :none)
      assert %Request{headers: headers} = result
      assert get_header(headers, "prefer") =~ "count=none"
    end

    test "combines multiple options", %{request: request} do
      result =
        QueryBuilder.insert(request, %{name: "Test"},
          on_conflict: "name",
          returning: :headers_only,
          count: :estimated
        )

      assert %Request{headers: headers} = result

      assert get_header(headers, "prefer") ==
               "return=headers_only,count=estimated,on_conflict=name,resolution=merge-duplicates"
    end

    test "ignores nil values in prefer header", %{request: request} do
      result = QueryBuilder.insert(request, %{})
      assert %Request{headers: headers} = result
      refute get_header(headers, "prefer") =~ "nil"
    end
  end

  describe "upsert/3" do
    test "creates POST request with upsert headers", %{request: request} do
      data = %{id: 1, name: "Updated"}
      result = QueryBuilder.upsert(request, data)
      assert %Request{method: :post, body: body, headers: headers} = result
      # Body is encoded as iodata for HTTP transmission
      assert is_list(body)
      assert get_header(headers, "prefer") =~ "resolution=merge-duplicates"
    end

    test "defaults to return representation", %{request: request} do
      result = QueryBuilder.upsert(request, %{})
      assert %Request{headers: headers} = result
      assert get_header(headers, "prefer") =~ "return=representation"
    end

    test "handles on_conflict for upsert", %{request: request} do
      result = QueryBuilder.upsert(request, %{}, on_conflict: "id")
      assert %Request{headers: headers, query: query} = result
      assert get_header(headers, "prefer") =~ "on_conflict=id"
      assert {"on_conflict", "id"} in query
    end

    test "allows custom returning option", %{request: request} do
      result = QueryBuilder.upsert(request, %{}, returning: :minimal)
      assert %Request{headers: headers} = result
      assert get_header(headers, "prefer") =~ "return=minimal"
    end

    test "allows custom count option", %{request: request} do
      result = QueryBuilder.upsert(request, %{}, count: :none)
      assert %Request{headers: headers} = result
      assert get_header(headers, "prefer") =~ "count=none"
    end
  end

  describe "update/3" do
    test "creates PATCH request with data", %{request: request} do
      data = %{status: "active"}
      result = QueryBuilder.update(request, data)
      assert %Request{method: :patch, body: body} = result
      # Body is encoded as iodata for HTTP transmission
      assert is_list(body)
    end

    test "sets default prefer headers for update", %{request: request} do
      result = QueryBuilder.update(request, %{})
      assert %Request{headers: headers} = result
      assert get_header(headers, "prefer") == "return=representation,count=exact"
    end

    test "allows custom returning preference", %{request: request} do
      result = QueryBuilder.update(request, %{}, returning: :headers_only)
      assert %Request{headers: headers} = result
      assert get_header(headers, "prefer") =~ "return=headers_only"
    end

    test "allows custom count preference", %{request: request} do
      result = QueryBuilder.update(request, %{}, count: :planned)
      assert %Request{headers: headers} = result
      assert get_header(headers, "prefer") =~ "count=planned"
    end

    test "handles empty data map", %{request: request} do
      result = QueryBuilder.update(request, %{})
      assert %Request{body: body} = result
      # Empty map is encoded as "{}"
      assert body == "{}"
    end
  end

  describe "delete/2" do
    test "creates DELETE request", %{request: request} do
      result = QueryBuilder.delete(request)
      assert %Request{method: :delete} = result
    end

    test "sets default prefer headers for delete", %{request: request} do
      result = QueryBuilder.delete(request)
      assert %Request{headers: headers} = result
      assert get_header(headers, "prefer") == "return=representation,count=exact"
    end

    test "allows custom returning preference", %{request: request} do
      result = QueryBuilder.delete(request, returning: :minimal)
      assert %Request{headers: headers} = result
      assert get_header(headers, "prefer") =~ "return=minimal"
    end

    test "allows custom count preference", %{request: request} do
      result = QueryBuilder.delete(request, count: :none)
      assert %Request{headers: headers} = result
      assert get_header(headers, "prefer") =~ "count=none"
    end

    test "combines options correctly", %{request: request} do
      result = QueryBuilder.delete(request, returning: :headers_only, count: :estimated)
      assert %Request{headers: headers} = result
      assert get_header(headers, "prefer") == "return=headers_only,count=estimated"
    end
  end

  describe "edge cases" do
    test "handles data with special characters", %{request: request} do
      data = %{
        name: "O'Brien",
        description: "Line 1\nLine 2",
        json: %{key: "value with \"quotes\""}
      }

      result = QueryBuilder.insert(request, data)
      assert %Request{body: body} = result
      # Body is encoded as iodata for HTTP transmission
      assert is_list(body)
    end

    test "handles nested maps in data", %{request: request} do
      data = %{
        profile: %{
          name: "John",
          settings: %{theme: "dark", notifications: true}
        }
      }

      result = QueryBuilder.update(request, data)
      assert %Request{body: body} = result
      # Body is encoded as iodata for HTTP transmission
      assert is_list(body)
    end

    test "handles list values in data", %{request: request} do
      data = %{
        tags: ["elixir", "phoenix", "postgrest"],
        numbers: [1, 2, 3]
      }

      result = QueryBuilder.insert(request, data)
      assert %Request{body: body} = result
      # Body is encoded as iodata for HTTP transmission
      assert is_list(body)
    end
  end
end
