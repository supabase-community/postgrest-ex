defmodule Supabase.PostgREST.SchemaDecoderTest do
  use ExUnit.Case, async: true

  alias Supabase.Fetcher.Response
  alias Supabase.PostgREST.SchemaDecoder

  defmodule TestSchema do
    defstruct [:id, :name, :email]
  end

  defmodule AnotherSchema do
    defstruct [:title, :content, :author_id]
  end

  describe "decode/2" do
    test "decodes successful single object response into provided schema" do
      response = %Response{
        status: 200,
        body: ~s({"id": 1, "name": "John Doe", "email": "john@example.com"}),
        headers: %{"content-type" => "application/json"}
      }

      assert {:ok, result} = SchemaDecoder.decode(response, schema: TestSchema)
      assert %TestSchema{id: 1, name: "John Doe", email: "john@example.com"} = result
    end

    test "decodes successful array response into list of schema structs" do
      response = %Response{
        status: 200,
        body: ~s([
          {"id": 1, "name": "John Doe", "email": "john@example.com"},
          {"id": 2, "name": "Jane Smith", "email": "jane@example.com"}
        ]),
        headers: %{"content-type" => "application/json"}
      }

      assert {:ok, results} = SchemaDecoder.decode(response, schema: TestSchema)

      assert [
               %TestSchema{id: 1, name: "John Doe", email: "john@example.com"},
               %TestSchema{id: 2, name: "Jane Smith", email: "jane@example.com"}
             ] = results
    end

    test "decodes empty array response into empty list" do
      response = %Response{
        status: 200,
        body: "[]",
        headers: %{"content-type" => "application/json"}
      }

      assert {:ok, []} = SchemaDecoder.decode(response, schema: TestSchema)
    end

    test "returns raw body for error responses (status >= 400)" do
      response = %Response{
        status: 404,
        body: ~s({"message": "Not found", "code": "PGRST116"}),
        headers: %{"content-type" => "application/json"}
      }

      assert {:ok, body} = SchemaDecoder.decode(response, schema: TestSchema)
      assert %{message: "Not found", code: "PGRST116"} = body
    end

    test "handles missing fields in response by setting them to nil in struct" do
      response = %Response{
        status: 200,
        body: ~s({"id": 1, "name": "John Doe"}),
        headers: %{"content-type" => "application/json"}
      }

      assert {:ok, result} = SchemaDecoder.decode(response, schema: TestSchema)
      assert %TestSchema{id: 1, name: "John Doe", email: nil} = result
    end

    test "ignores extra fields in response that aren't in schema" do
      response = %Response{
        status: 200,
        body: ~s({"id": 1, "name": "John Doe", "email": "john@example.com", "extra": "field"}),
        headers: %{"content-type" => "application/json"}
      }

      assert {:ok, result} = SchemaDecoder.decode(response, schema: TestSchema)
      assert %TestSchema{id: 1, name: "John Doe", email: "john@example.com"} = result
    end

    test "works with different schema structs" do
      response = %Response{
        status: 201,
        body: ~s({"title": "My Post", "content": "Hello World", "author_id": 42}),
        headers: %{"content-type" => "application/json"}
      }

      assert {:ok, result} = SchemaDecoder.decode(response, schema: AnotherSchema)
      assert %AnotherSchema{title: "My Post", content: "Hello World", author_id: 42} = result
    end

    test "handles 2xx status codes as successful" do
      for status <- [200, 201, 202, 204] do
        response = %Response{
          status: status,
          body: ~s({"id": 1, "name": "Test"}),
          headers: %{"content-type" => "application/json"}
        }

        assert {:ok, result} = SchemaDecoder.decode(response, schema: TestSchema)
        assert %TestSchema{id: 1, name: "Test", email: nil} = result
      end
    end

    test "handles 3xx status codes as successful" do
      response = %Response{
        status: 304,
        body: ~s({"id": 1, "name": "Test"}),
        headers: %{"content-type" => "application/json"}
      }

      assert {:ok, result} = SchemaDecoder.decode(response, schema: TestSchema)
      assert %TestSchema{id: 1, name: "Test", email: nil} = result
    end

    test "returns error when JSON parsing fails" do
      response = %Response{
        status: 200,
        body: "invalid json",
        headers: %{"content-type" => "application/json"}
      }

      assert {:error, _} = SchemaDecoder.decode(response, schema: TestSchema)
    end

    test "raises when schema option is missing" do
      response = %Response{
        status: 200,
        body: "{}",
        headers: %{"content-type" => "application/json"}
      }

      assert_raise KeyError, fn ->
        SchemaDecoder.decode(response, [])
      end
    end
  end
end
