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
end
