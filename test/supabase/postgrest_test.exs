defmodule Supabase.PostgRESTTest do
  use ExUnit.Case

  alias Supabase.PostgREST
  alias Supabase.PostgREST.FilterBuilder
  alias Supabase.PostgREST.QueryBuilder

  # Mock the Supabase.Client for the test environment
  setup do
    client = %Supabase.Client{
      conn: %{api_key: "test_key", base_url: "http://example.com"},
      db: %{schema: "public"}
    }

    {:ok, client: client}
  end

  describe "from/2" do
    test "initializes a QueryBuilder correctly", %{client: client} do
      table = "users"

      assert %QueryBuilder{table: ^table} = PostgREST.from(client, table)
    end
  end

  describe "select/3" do
    test "builds a select query with specific columns", %{client: client} do
      query_builder = QueryBuilder.new("users", client)
      columns = ["id", "name", "email"]
      opts = [count: :exact, returning: true]

      result = PostgREST.select(query_builder, columns, opts)
      assert %FilterBuilder{} = result
      assert result.params["select"] == "id,name,email"
      assert result.headers["prefer"] == "count=exact"
    end

    test "builds a select query with all columns using '*'", %{client: client} do
      query_builder = QueryBuilder.new("users", client)
      opts = [count: :exact, returning: false]

      result = PostgREST.select(query_builder, "*", opts)
      assert %FilterBuilder{} = result
      assert result.params["select"] == "*"
      assert result.headers["prefer"] == "count=exact"
    end
  end

  describe "insert/3" do
    test "builds an insert query with correct headers and body", %{client: client} do
      query_builder = QueryBuilder.new("users", client)
      data = %{name: "John Doe", age: 28}
      opts = [on_conflict: "name", returning: :minimal, count: :exact]

      result = PostgREST.insert(query_builder, data, opts)
      assert %FilterBuilder{} = result
      assert result.method == :post

      assert result.headers["prefer"] ==
               "return=minimal,count=exact,on_conflict=name,resolution=merge-duplicates"
    end
  end

  describe "update/3" do
    test "creates an update operation with custom options", %{client: client} do
      query_builder = QueryBuilder.new("users", client)
      data = %{name: "Jane Doe"}
      opts = [returning: :representation, count: :exact]

      result = PostgREST.update(query_builder, data, opts)
      assert %FilterBuilder{} = result
      assert result.method == :patch
      assert result.headers["prefer"] == "return=representation,count=exact"
    end
  end

  describe "delete/2" do
    test "builds a delete query with custom preferences", %{client: client} do
      query_builder = QueryBuilder.new("users", client)
      opts = [returning: :representation, count: :exact]

      result = PostgREST.delete(query_builder, opts)
      assert %FilterBuilder{} = result
      assert result.method == :delete
      assert result.headers["prefer"] == "return=representation,count=exact"
    end
  end

  describe "upsert/3" do
    test "builds an upsert query with conflict resolution", %{client: client} do
      query_builder = QueryBuilder.new("users", client)
      data = %{name: "Jane Doe"}
      opts = [on_conflict: "name", returning: :representation, count: :exact]

      result = PostgREST.upsert(query_builder, data, opts)
      assert %FilterBuilder{} = result
      assert result.method == :post

      assert result.headers["prefer"] ==
               "resolution=merge-duplicates,return=representation,count=exact"
    end
  end

  describe "filter functions" do
    setup do
      client = %Supabase.Client{
        conn: %{api_key: "test_key", base_url: "http://example.com"}
      }

      query_builder = QueryBuilder.new("users", client)
      filter_builder = FilterBuilder.from_query_builder(query_builder)
      {:ok, filter_builder: filter_builder}
    end

    test "eq function adds an equality filter", %{filter_builder: fb} do
      assert %FilterBuilder{params: %{"id" => "eq.123"}} = PostgREST.eq(fb, "id", 123)
    end

    test "neq function adds a not-equal filter", %{filter_builder: fb} do
      assert %FilterBuilder{params: %{"status" => "neq.inactive"}} =
               PostgREST.neq(fb, "status", "inactive")
    end

    test "gt function adds a greater-than filter", %{filter_builder: fb} do
      assert %FilterBuilder{params: %{"age" => "gt.21"}} = PostgREST.gt(fb, "age", 21)
    end

    test "lte function adds a less-than-or-equal filter", %{filter_builder: fb} do
      assert %FilterBuilder{params: %{"age" => "lte.65"}} = PostgREST.lte(fb, "age", 65)
    end

    test "like function adds a LIKE SQL pattern filter", %{filter_builder: fb} do
      assert %FilterBuilder{params: %{"name" => "like.%John%"}} =
               PostgREST.like(fb, "name", "%John%")
    end

    test "ilike function adds a case-insensitive LIKE filter", %{filter_builder: fb} do
      assert %FilterBuilder{params: %{"name" => "ilike.%john%"}} =
               PostgREST.ilike(fb, "name", "%john%")
    end

    test "in function checks if a column's value is within a specified list", %{
      filter_builder: fb
    } do
      assert %FilterBuilder{params: %{"status" => "in.(active,pending,closed)"}} =
               PostgREST.in(fb, "status", ["active", "pending", "closed"])
    end
  end
end
