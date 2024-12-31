defmodule Supabase.PostgRESTTest do
  use ExUnit.Case

  alias Supabase.PostgREST
  alias Supabase.PostgREST.Builder

  setup do
    client = Supabase.init_client!("http://some/url", "test-api-key")

    {:ok, %{client: client}}
  end

  describe "from/2" do
    test "initializes a Builder correctly", %{client: client} do
      table = "users"

      assert %Builder{url: url} = PostgREST.from(client, table)
      assert url.path =~ table
    end
  end

  describe "select/3" do
    test "builds a select query with specific columns", %{client: client} do
      builder = Builder.new(client, relation: "users")
      columns = ["id", "name", "email"]
      opts = [count: :exact, returning: true]

      result = PostgREST.select(builder, columns, opts)
      assert %Builder{} = result
      assert result.params["select"] == "id,name,email"
      assert result.headers["prefer"] == "count=exact"
    end

    test "builds a select query with all columns using '*'", %{client: client} do
      builder = Builder.new(client, relation: "users")
      opts = [count: :exact, returning: false]

      result = PostgREST.select(builder, "*", opts)
      assert %Builder{} = result
      assert result.params["select"] == "*"
      assert result.headers["prefer"] == "count=exact"
    end
  end

  describe "insert/3" do
    test "builds an insert query with correct headers and body", %{client: client} do
      builder = Builder.new(client, relation: "users")
      data = %{name: "John Doe", age: 28}
      opts = [on_conflict: "name", returning: :minimal, count: :exact]

      result = PostgREST.insert(builder, data, opts)
      assert %Builder{} = result
      assert result.method == :post

      assert result.headers["prefer"] ==
               "return=minimal,count=exact,on_conflict=name,resolution=merge-duplicates"
    end
  end

  describe "update/3" do
    test "creates an update operation with custom options", %{client: client} do
      builder = Builder.new(client, relation: "users")
      data = %{name: "Jane Doe"}
      opts = [returning: :representation, count: :exact]

      result = PostgREST.update(builder, data, opts)
      assert %Builder{} = result
      assert result.method == :patch
      assert result.headers["prefer"] == "return=representation,count=exact"
    end
  end

  describe "delete/2" do
    test "builds a delete query with custom preferences", %{client: client} do
      builder = Builder.new(client, relation: "users")
      opts = [returning: :representation, count: :exact]

      result = PostgREST.delete(builder, opts)
      assert %Builder{} = result
      assert result.method == :delete
      assert result.headers["prefer"] == "return=representation,count=exact"
    end
  end

  describe "upsert/3" do
    test "builds an upsert query with conflict resolution", %{client: client} do
      builder = Builder.new(client, relation: "users")
      data = %{name: "Jane Doe"}
      opts = [on_conflict: "name", returning: :representation, count: :exact]

      result = PostgREST.upsert(builder, data, opts)
      assert %Builder{} = result
      assert result.method == :post

      assert result.headers["prefer"] ==
               "resolution=merge-duplicates,return=representation,count=exact"
    end
  end

  describe "filter functions" do
    setup ctx do
      builder = Builder.new(ctx.client, relation: "users")
      {:ok, Map.put(ctx, :builder, builder)}
    end

    test "eq function adds an equality filter", %{builder: fb} do
      assert %Builder{params: %{"id" => "eq.123"}} = PostgREST.eq(fb, "id", 123)
    end

    test "neq function adds a not-equal filter", %{builder: fb} do
      assert %Builder{params: %{"status" => "neq.inactive"}} =
               PostgREST.neq(fb, "status", "inactive")
    end

    test "gt function adds a greater-than filter", %{builder: fb} do
      assert %Builder{params: %{"age" => "gt.21"}} = PostgREST.gt(fb, "age", 21)
    end

    test "lte function adds a less-than-or-equal filter", %{builder: fb} do
      assert %Builder{params: %{"age" => "lte.65"}} = PostgREST.lte(fb, "age", 65)
    end

    test "like function adds a LIKE SQL pattern filter", %{builder: fb} do
      assert %Builder{params: %{"name" => "like.%John%"}} =
               PostgREST.like(fb, "name", "%John%")
    end

    test "ilike function adds a case-insensitive LIKE filter", %{builder: fb} do
      assert %Builder{params: %{"name" => "ilike.%john%"}} =
               PostgREST.ilike(fb, "name", "%john%")
    end

    test "within function checks if a column's value is within a specified list", %{
      builder: fb
    } do
      assert %Builder{params: %{"status" => "in.(active,pending,closed)"}} =
               PostgREST.within(fb, "status", ["active", "pending", "closed"])
    end
  end
end
