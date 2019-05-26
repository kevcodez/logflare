defmodule Logflare.Logs.RejectedEventsTest do
  @moduledoc false
  alias Logflare.Logs.RejectedEvents
  alias Logflare.{Sources}
  import Logflare.DummyFactory
  use Logflare.DataCase

  setup do
    s1 = insert(:source)
    s2 = insert(:source)
    sources = [s1, s2]
    u1 = insert(:user, api_key: @api_key, sources: sources)
    {:ok, users: [u1], sources: sources}
  end

  describe "rejected logs module" do
    test "inserts logs for source and error", %{sources: [s1]} do
      source = Sources.get_by_id(s1.token)

      raw_logs = [
        %{"log_entry" => "test", "metadata" => %{"ip" => "0.0.0.0"}},
        %{
          "log_entry" => "test",
          "metadata" => %{"ip" => %{"version" => 4, "address" => "0.0.0.0"}}
        }
      ]

      error = Logflare.Validator.DeepFieldTypes.Error

      _ = RejectedEvents.insert(source, error, raw_logs)
      cached = RejectedEvents.get_by_source(source)

      assert cached[error] === raw_logs
    end

    test "gets logs for all sources for user", %{users: [u1], sources: [s1, s2]} do
      source1 = Sources.get_by_id(s1.token)
      source2 = Sources.get_by_id(s2.token)

      raw_logs_source_1 = [
        %{"log_entry" => "case1", "metadata" => %{"ip" => "0.0.0.0"}},
        %{
          "log_entry" => "case1",
          "metadata" => %{"ip" => %{"version" => 4, "address" => "0.0.0.0"}}
        }
      ]

      raw_logs_source_2 = [
        %{"log_entry" => "case2", "metadata" => %{"ip" => "0.0.0.0"}},
        %{
          "log_entry" => "case2",
          "metadata" => %{"ip" => %{"version" => 4, "address" => "0.0.0.0"}}
        }
      ]

      error = Logflare.Validator.DeepFieldTypes.Error

      _ = RejectedEvents.insert(source1, error, raw_logs_source_1)
      _ = RejectedEvents.insert(source2, error, raw_logs_source_2)

      result = RejectedEvents.get_by_user(u1)

      assert is_map(result[source1.token])
      assert is_map(result[source2.token])
    end
  end
end
