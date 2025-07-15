defmodule Supabase.PostgREST.FilterBuilderTest do
  use ExUnit.Case, async: true

  import Supabase.PostgREST.FilterBuilder, only: [process_condition: 1]

  test "process not condition for a single clause" do
    result = process_condition({:not, {:eq, "status", "active"}})
    assert result == "not.status.eq.active"
  end

  test "process not condition with nested and" do
    result = process_condition({:not, {:and, [{:gt, "age", 18}, {:eq, "status", "active"}]}})
    assert result == "not.and(age.gt.18,status.eq.active)"
  end

  test "process not condition with nested or" do
    result = process_condition({:not, {:or, [{:lt, "age", 18}, {:eq, "status", "inactive"}]}})
    assert result == "not.or(age.lt.18,status.eq.inactive)"
  end

  test "process deeply nested not condition" do
    result =
      process_condition(
        {:not,
         {:or,
          [{:not, {:eq, "status", "active"}}, {:and, [{:lt, "age", 18}, {:gt, "score", 90}]}]}}
      )

    assert result == "not.or(not.status.eq.active,and(age.lt.18,score.gt.90))"
  end

  test "process simple condition with eq operator" do
    assert process_condition({:eq, "age", 18}) == "age.eq.18"
  end

  test "process simple condition with gt operator" do
    assert process_condition({:gt, "age", 18}) == "age.gt.18"
  end

  test "process and condition" do
    result = process_condition({:and, [{:gt, "age", 18}, {:eq, "status", "active"}]})
    assert result == "and(age.gt.18,status.eq.active)"
  end

  test "process or condition with nested and" do
    result =
      process_condition(
        {:or, [{:eq, "status", "active"}, {:and, [{:lt, "age", 18}, {:gt, "score", 90}]}]}
      )

    assert result == "or(status.eq.active,and(age.lt.18,score.gt.90))"
  end

  test "process any modifier condition" do
    result =
      process_condition({:eq, "tags", ["elixir", "phoenix"], any: true})

    assert result == "tags=eq(any).{elixir,phoenix}"
  end

  test "process all modifier condition" do
    result =
      process_condition({:like, "tags", ["*backend*", "*frontend*"], all: true})

    assert result == "tags=like(all).{*backend*,*frontend*}"
  end

  test "raises error for invalid operator" do
    assert_raise FunctionClauseError, fn ->
      process_condition({:invalid_op, "age", 18})
    end
  end

  test "process empty and condition" do
    assert process_condition({:and, []}) == "and()"
  end

  test "process empty or condition" do
    assert process_condition({:or, []}) == "or()"
  end

  describe "complex filter combinations" do
    test "handles triple nested conditions" do
      result =
        process_condition(
          {:and,
           [
             {:or, [{:eq, "type", "admin"}, {:eq, "type", "moderator"}]},
             {:not,
              {:and,
               [
                 {:lt, "created_at", "2023-01-01"},
                 {:or, [{:eq, "status", "banned"}, {:eq, "status", "suspended"}]}
               ]}}
           ]}
        )

      assert result ==
               "and(or(type.eq.admin,type.eq.moderator),not.and(created_at.lt.2023-01-01,or(status.eq.banned,status.eq.suspended)))"
    end

    test "handles multiple not operators in sequence" do
      result = process_condition({:not, {:not, {:eq, "active", true}}})
      assert result == "not.not.active.eq.true"
    end

    test "processes complex array conditions with modifiers" do
      result =
        process_condition(
          {:and,
           [
             {:eq, "roles", ["admin", "editor"], any: true},
             {:not, {:eq, "permissions", ["delete", "archive"], all: true}}
           ]}
        )

      assert result ==
               "and(roles=eq(any).{admin,editor},not.permissions=eq(all).{delete,archive})"
    end

    test "handles mixed operator types" do
      result =
        process_condition(
          {:or,
           [
             {:gte, "score", 90},
             {:and, [{:between, "score", [80, 89]}, {:eq, "bonus", true}]},
             {:lte, "score", 50}
           ]}
        )

      assert result == "or(score.gte.90,and(score.between.[80,89],bonus.eq.true),score.lte.50)"
    end
  end

  describe "additional operators" do
    test "process lt (less than) operator" do
      assert process_condition({:lt, "price", 100}) == "price.lt.100"
    end

    test "process gte (greater than or equal) operator" do
      assert process_condition({:gte, "quantity", 5}) == "quantity.gte.5"
    end

    test "process lte (less than or equal) operator" do
      assert process_condition({:lte, "stock", 10}) == "stock.lte.10"
    end

    test "process neq (not equal) operator" do
      assert process_condition({:neq, "status", "deleted"}) == "status.neq.deleted"
    end

    test "process like operator" do
      assert process_condition({:like, "email", "%@example.com"}) == "email.like.%@example.com"
    end

    test "process ilike (case insensitive like) operator" do
      assert process_condition({:ilike, "name", "%john%"}) == "name.ilike.%john%"
    end

    test "process in operator" do
      assert process_condition({:in, "category", ["electronics", "books", "clothing"]}) ==
               "category.in.(electronics,books,clothing)"
    end

    test "process is operator for null checks" do
      assert process_condition({:is, "deleted_at", nil}) == "deleted_at.is.null"
      assert process_condition({:is, "verified", true}) == "verified.is.true"
      assert process_condition({:is, "archived", false}) == "archived.is.false"
    end

    test "process between operator" do
      assert process_condition({:between, "age", [18, 65]}) == "age.between.[18,65]"
    end
  end

  describe "edge cases and error handling" do
    test "handles string values with special characters" do
      assert process_condition({:eq, "name", "O'Brien"}) == "name.eq.O'Brien"

      assert process_condition({:eq, "description", "Line 1\nLine 2"}) ==
               "description.eq.Line 1\nLine 2"
    end

    test "handles numeric values" do
      assert process_condition({:eq, "price", 19.99}) == "price.eq.19.99"
      assert process_condition({:gt, "count", 1000}) == "count.gt.1000"
    end

    test "handles boolean values" do
      assert process_condition({:eq, "active", true}) == "active.eq.true"
      assert process_condition({:neq, "archived", false}) == "archived.neq.false"
    end

    test "single element and/or conditions" do
      assert process_condition({:and, [{:eq, "status", "active"}]}) == "and(status.eq.active)"
      assert process_condition({:or, [{:gt, "age", 18}]}) == "or(age.gt.18)"
    end

    test "deeply nested empty conditions" do
      assert process_condition({:and, [{:or, []}, {:and, []}]}) == "and(or(),and())"
    end

    test "array values without modifiers default behavior" do
      # This should raise or have specific behavior - adjust based on actual implementation
      assert process_condition({:eq, "tags", ["tag1", "tag2"]}) == "tags.eq.[tag1,tag2]"
    end
  end

  describe "filter builder integration" do
    alias Supabase.Fetcher.Request
    alias Supabase.PostgREST.FilterBuilder

    setup do
      client = Supabase.init_client!("http://example.com", "test-key")
      request = Request.new(client)
      {:ok, %{request: request}}
    end

    test "multiple filter functions create proper query params", %{request: request} do
      result =
        request
        |> FilterBuilder.eq("status", "active")
        |> FilterBuilder.gt("age", 18)
        |> FilterBuilder.within("role", ["admin", "moderator"])

      assert %Request{query: query} = result
      assert {"status", "eq.active"} in query
      assert {"age", "gt.18"} in query
      assert {"role", "in.(admin,moderator)"} in query
    end

    test "filter functions handle nil values", %{request: request} do
      result = FilterBuilder.is(request, "deleted_at", nil)
      assert %Request{query: query} = result
      assert {"deleted_at", "is.null"} in query
    end
  end
end
