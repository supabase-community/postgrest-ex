defmodule Supabase.PostgREST.TransformBuilderTest do
  use ExUnit.Case, async: true

  import Supabase.PostgREST.Helpers

  alias Supabase.Fetcher.Request
  alias Supabase.PostgREST.TransformBuilder

  setup do
    client = Supabase.init_client!("http://example.com", "test-key")
    request = Request.new(client)
    {:ok, %{request: request}}
  end

  describe "limit/3" do
    test "adds limit query parameter", %{request: request} do
      result = TransformBuilder.limit(request, 10)
      assert %Request{query: query} = result
      assert {"limit", "10"} in query
    end

    test "adds foreign table limit when specified", %{request: request} do
      result = TransformBuilder.limit(request, 5, foreign_table: "posts")
      assert %Request{query: query} = result
      assert {"posts.limit", "5"} in query
    end

    test "converts integer limit to string", %{request: request} do
      result = TransformBuilder.limit(request, 100)
      assert %Request{query: query} = result
      assert {"limit", "100"} in query
    end
  end

  describe "order/3" do
    test "adds order query parameter with default desc and nullslast", %{request: request} do
      result = TransformBuilder.order(request, "created_at")
      assert %Request{query: query} = result
      assert Enum.any?(query, fn {k, v} -> k == "order" and v == "created_at.desc.nullslast" end)
    end

    test "adds ascending order when specified", %{request: request} do
      result = TransformBuilder.order(request, "name", asc: true)
      assert %Request{query: query} = result
      assert Enum.any?(query, fn {k, v} -> k == "order" and v == "name.asc.nullslast" end)
    end

    test "adds nulls first when specified", %{request: request} do
      result = TransformBuilder.order(request, "score", null_first: true)
      assert %Request{query: query} = result
      assert Enum.any?(query, fn {k, v} -> k == "order" and v == "score.desc.nullsfirst" end)
    end

    test "combines asc and null_first options", %{request: request} do
      result = TransformBuilder.order(request, "id", asc: true, null_first: true)
      assert %Request{query: query} = result
      assert Enum.any?(query, fn {k, v} -> k == "order" and v == "id.asc.nullsfirst" end)
    end

    test "adds foreign table order when specified", %{request: request} do
      result = TransformBuilder.order(request, "title", foreign_table: "posts", asc: true)
      assert %Request{query: query} = result
      assert Enum.any?(query, fn {k, v} -> k == "posts.order" and v == "title.asc.nullslast" end)
    end

    test "allows multiple order calls", %{request: request} do
      result =
        request
        |> TransformBuilder.order("created_at", asc: false)
        |> TransformBuilder.order("name", asc: true)

      assert %Request{query: query} = result
      order_values = for {k, v} <- query, k == "order", do: v
      assert "created_at.desc.nullslast,name.asc.nullslast" in order_values
    end
  end

  describe "range/4" do
    test "adds offset and limit for range", %{request: request} do
      result = TransformBuilder.range(request, 10, 20)
      assert %Request{query: query} = result
      assert {"offset", "10"} in query
      # 20 - 10 + 1
      assert {"limit", "11"} in query
    end

    test "calculates correct limit for inclusive range", %{request: request} do
      result = TransformBuilder.range(request, 0, 9)
      assert %Request{query: query} = result
      assert {"offset", "0"} in query
      # 9 - 0 + 1
      assert {"limit", "10"} in query
    end

    test "handles single item range", %{request: request} do
      result = TransformBuilder.range(request, 5, 5)
      assert %Request{query: query} = result
      assert {"offset", "5"} in query
      # 5 - 5 + 1
      assert {"limit", "1"} in query
    end

    test "adds foreign table range when specified", %{request: request} do
      result = TransformBuilder.range(request, 2, 7, foreign_table: "comments")
      assert %Request{query: query} = result
      assert {"comments.offset", "2"} in query
      # 7 - 2 + 1
      assert {"comments.limit", "6"} in query
    end

    test "works with float numbers", %{request: request} do
      result = TransformBuilder.range(request, 1.0, 5.0)
      assert %Request{query: query} = result
      assert {"offset", "1.0"} in query
      # 5.0 - 1.0 + 1
      assert {"limit", "5.0"} in query
    end
  end

  describe "single/1" do
    test "sets custom media type to pgrst_object", %{request: request} do
      result = TransformBuilder.single(request)
      assert %Request{} = result
      assert get_header(result.headers, "accept") == "application/vnd.pgrst.object+json"
    end
  end

  describe "maybe_single/1" do
    test "sets media type to json for GET requests", %{request: request} do
      get_request = %{request | method: :get}
      result = TransformBuilder.maybe_single(get_request)
      assert %Request{} = result
      assert get_header(result.headers, "accept") == "application/json"
    end

    test "sets media type to pgrst_object for non-GET requests", %{request: request} do
      post_request = %{request | method: :post}
      result = TransformBuilder.maybe_single(post_request)
      assert %Request{} = result
      assert get_header(result.headers, "accept") == "application/vnd.pgrst.object+json"
    end

    test "handles other HTTP methods", %{request: request} do
      for method <- [:post, :patch, :put, :delete] do
        req = %{request | method: method}
        result = TransformBuilder.maybe_single(req)
        assert %Request{} = result
        assert get_header(result.headers, "accept") == "application/vnd.pgrst.object+json"
      end
    end
  end

  describe "csv/1" do
    test "sets accept header to text/csv", %{request: request} do
      result = TransformBuilder.csv(request)
      assert %Request{} = result
      assert get_header(result.headers, "accept") == "text/csv"
    end
  end

  describe "geojson/1" do
    test "sets accept header to application/geo+json", %{request: request} do
      result = TransformBuilder.geojson(request)
      assert %Request{} = result
      assert get_header(result.headers, "accept") == "application/geo+json"
    end
  end

  describe "explain/2" do
    test "sets explain header with default options", %{request: request} do
      # Set a default accept header as the function expects one
      request = Request.with_headers(request, %{"accept" => "application/json"})
      result = TransformBuilder.explain(request)
      assert %Request{} = result
      assert get_header(result.headers, "accept") =~ "application/vnd.pgrst.plan+text"
      assert get_header(result.headers, "accept") =~ "for=application/json"
      assert get_header(result.headers, "accept") =~ "options:"
    end

    test "includes analyze option when true", %{request: request} do
      request = Request.with_headers(request, %{"accept" => "application/json"})
      result = TransformBuilder.explain(request, analyze: true)
      assert %Request{} = result
      assert get_header(result.headers, "accept") =~ "analyze"
    end

    test "includes multiple options when specified", %{request: request} do
      request = Request.with_headers(request, %{"accept" => "application/json"})
      result = TransformBuilder.explain(request, analyze: true, verbose: true, buffers: true)
      assert %Request{} = result
      assert get_header(result.headers, "accept") =~ "analyze"
      assert get_header(result.headers, "accept") =~ "verbose"
      assert get_header(result.headers, "accept") =~ "buffers"
    end

    test "excludes false options", %{request: request} do
      request = Request.with_headers(request, %{"accept" => "application/json"})
      result = TransformBuilder.explain(request, analyze: false, verbose: true)
      assert %Request{} = result
      assert get_header(result.headers, "accept") =~ "verbose"
      refute get_header(result.headers, "accept") =~ "analyze"
    end

    test "sets json format when specified", %{request: request} do
      request = Request.with_headers(request, %{"accept" => "application/json"})
      result = TransformBuilder.explain(request, format: :json)
      assert %Request{} = result
      assert get_header(result.headers, "accept") =~ "application/vnd.pgrst.plan+json"
    end

    test "defaults to text format for invalid format", %{request: request} do
      request = Request.with_headers(request, %{"accept" => "application/json"})
      result = TransformBuilder.explain(request, format: :invalid)
      assert %Request{} = result
      assert get_header(result.headers, "accept") =~ "application/vnd.pgrst.plan+text"
    end

    test "preserves original accept header in for parameter", %{request: request} do
      request = Request.with_headers(request, %{"accept" => "text/csv"})
      result = TransformBuilder.explain(request)
      assert %Request{} = result
      assert get_header(result.headers, "accept") =~ "for=text/csv"
    end
  end

  describe "rollback/1" do
    test "adds tx=rollback to prefer header", %{request: request} do
      result = TransformBuilder.rollback(request)
      assert %Request{} = result
      assert get_header(result.headers, "prefer") == "tx=rollback"
    end

    test "merges with existing prefer header", %{request: request} do
      request = Request.with_headers(request, %{"prefer" => "return=minimal"})
      result = TransformBuilder.rollback(request)
      assert %Request{} = result
      assert get_header(result.headers, "prefer") == "return=minimal,tx=rollback"
    end
  end

  describe "returning/2" do
    test "adds select=* and return=representation when no columns specified", %{request: request} do
      result = TransformBuilder.returning(request)
      assert %Request{query: query} = result
      assert {"select", "*"} in query
      assert get_header(result.headers, "prefer") =~ "return=representation"
    end

    test "adds specific columns when provided as list", %{request: request} do
      result = TransformBuilder.returning(request, ["id", "name", "email"])
      assert %Request{query: query} = result
      assert {"select", "id,name,email"} in query
      assert get_header(result.headers, "prefer") =~ "return=representation"
    end

    test "trims whitespace from column names", %{request: request} do
      result = TransformBuilder.returning(request, ["id ", " name", " email "])
      assert %Request{query: query} = result
      assert {"select", "id,name,email"} in query
    end

    test "preserves quoted column names", %{request: request} do
      result = TransformBuilder.returning(request, ["\"special column\"", "normal"])
      assert %Request{query: query} = result
      assert {"select", "\"special column\",normal"} in query
    end

    test "handles empty list by defaulting to *", %{request: request} do
      result = TransformBuilder.returning(request, [])
      assert %Request{query: query} = result
      assert {"select", "*"} in query
    end

    test "merges with existing prefer header", %{request: request} do
      request = Request.with_headers(request, %{"prefer" => "count=exact"})
      result = TransformBuilder.returning(request, ["id"])
      assert %Request{} = result
      assert get_header(result.headers, "prefer") == "count=exact,return=representation"
    end
  end
end
