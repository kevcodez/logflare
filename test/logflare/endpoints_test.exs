defmodule Logflare.EndpointsTest do
  @moduledoc false
  use Logflare.DataCase
  alias Logflare.Endpoints
  alias Logflare.Endpoints.Query

  test "list_endpoints_by" do
    %{id: id, name: name} = insert(:endpoint)
    assert [%{id: ^id}] = Endpoints.list_endpoints_by(name: name)
  end

  test "get_endpoint_query/1 retrieves endpoint" do
    %{id: id} = insert(:endpoint)
    assert %Query{id: ^id} = Endpoints.get_endpoint_query(id)
  end

  test "get_by/1" do
    endpoint = insert(:endpoint, name: "some endpoint")
    assert endpoint.id == Endpoints.get_by(name: "some endpoint").id
  end

  test "get_query_by_token/1" do
    %{id: id, token: token} = insert(:endpoint)
    assert %Query{id: ^id} = Endpoints.get_query_by_token(token)
  end

  test "get_mapped_query_by_token/1 transforms renamed source names correctly" do
    user = insert(:user)
    source = insert(:source, user: user, name: "my_table")

    endpoint =
      insert(:endpoint,
        user: user,
        query: "select a from my_table",
        source_mapping: %{"my_table" => source.token}
      )

    # rename the source
    Ecto.Changeset.change(source, name: "new")
    |> Logflare.Repo.update()

    assert %Query{query: mapped_query} = Endpoints.get_mapped_query_by_token(endpoint.token)
    assert String.downcase(mapped_query) == "select a from new"
  end

  test "update_query/2 " do
    user = insert(:user)
    insert(:source, user: user, name: "my_table")
    endpoint = insert(:endpoint, user: user, query: "select current_datetime() as date")
    sql = "select a from my_table"
    assert {:ok, %{query: ^sql}} = Endpoints.update_query(endpoint, %{query: sql})

    # does not allow updating of query with unknown sources
    assert {:error, %Ecto.Changeset{}} =
             Endpoints.update_query(endpoint, %{query: "select b from unknown"})
  end

  test "parse_query_string/1" do
    assert {:ok, %{parameters: ["testing"]}} =
             Endpoints.parse_query_string("select @testing as date")
  end

  test "sandboxed endpoints" do
    user = insert(:user)
    insert(:source, user: user, name: "c")
    # sandbox query does not need to have sandboxable=true, just needs to be a CTE
    sandbox_query =
      insert(:endpoint, user: user, query: "with u as (select b from c) select d from u")

    assert {:ok, sandboxed} =
             Endpoints.create_sandboxed_query(user, sandbox_query, %{
               name: "abc",
               query: "select r from u"
             })

    assert %{name: "abc", query: "select r from u", sandboxable: false} = sandboxed

    # non-cte
    invalid_sandbox = insert(:endpoint, user: user)

    assert {:error, :no_cte} =
             Endpoints.create_sandboxed_query(user, invalid_sandbox, %{
               name: "abcd",
               query: "select r from u"
             })
  end

  describe "running queries" do
    setup do
      # mock goth behaviour
      Goth
      |> stub(:fetch, fn _mod -> {:ok, %Goth.Token{token: "auth-token"}} end)

      :ok
    end

    test "run an endpoint query without caching" do
      GoogleApi.BigQuery.V2.Api.Jobs
      |> expect(:bigquery_jobs_query, 1, fn _conn, _proj_id, _opts ->
        {:ok, TestUtils.gen_bq_response([%{"testing" => "123"}])}
      end)

      insert(:plan)
      user = insert(:user)
      insert(:source, user: user, name: "c")
      endpoint = insert(:endpoint, user: user, query: "select current_datetime() as testing")
      assert {:ok, %{rows: [%{"testing" => _}]}} = Endpoints.run_query(endpoint)
    end

    test "run_query_string/3" do
      GoogleApi.BigQuery.V2.Api.Jobs
      |> expect(:bigquery_jobs_query, 1, fn _conn, _proj_id, _opts ->
        {:ok, TestUtils.gen_bq_response([%{"testing" => "123"}])}
      end)

      insert(:plan)
      user = insert(:user)
      insert(:source, user: user, name: "c")
      query_string = "select current_datetime() as testing"
      assert {:ok, %{rows: [%{"testing" => _}]}} = Endpoints.run_query_string(user, query_string)
    end

    test "run_cached_query/1" do
      GoogleApi.BigQuery.V2.Api.Jobs
      |> expect(:bigquery_jobs_query, 1, fn _conn, _proj_id, _opts ->
        {:ok, TestUtils.gen_bq_response([%{"testing" => "123"}])}
      end)

      insert(:plan)
      user = insert(:user)
      endpoint = insert(:endpoint, user: user, query: "select current_datetime() as testing")
      _pid = start_supervised!({Logflare.Endpoints.Cache, {endpoint, %{}}})
      assert {:ok, %{rows: [%{"testing" => _}]}} = Endpoints.run_cached_query(endpoint)
      # 2nd query should hit local cache
      assert {:ok, %{rows: [%{"testing" => _}]}} = Endpoints.run_cached_query(endpoint)
    end
  end
end
