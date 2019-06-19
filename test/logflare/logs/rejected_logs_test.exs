defmodule Logflare.Logs.RejectedLogEventsTest do
  @moduledoc false
  alias Logflare.Logs.RejectedLogEvents
  alias Logflare.{Sources, Source, Users, LogEvent}
  import Logflare.DummyFactory
  use Logflare.DataCase
  use Placebo

  setup do
    s1 = build(:source)
    s2 = build(:source)
    sources = [s1, s2]
    u1 = insert(:user, sources: sources)

    allow(Source.Data.get_rate()) |> exec(fn _ -> 0 end)
    allow(Source.Data.get_latest_date()) |> exec(fn _ -> 0 end)
    allow(Source.Data.get_avg_rate()) |> exec(fn _ -> 0 end)
    allow(Source.Data.get_max_rate()) |> exec(fn _ -> 0 end)
    allow(Source.Data.get_buffer()) |> exec(fn _ -> 0 end)
    allow(Source.Data.get_total_inserts()) |> exec(fn _ -> 0 end)

    {:ok, users: [u1], sources: sources}
  end

  describe "rejected logs module" do
    test "inserts logs for source and validator", %{sources: [s1, _]} do
      validator = Logflare.Logs.Validators.EqDeepFieldTypes

      source = Sources.get_by(token: s1.token)
      timestamp = System.system_time(:microsecond)

      log_event = %LogEvent{
        params: %{
          "message" => "test",
          "metadata" => %{
            "ip" => "0.0.0.0"
          }
        },
        validation_error: validator.message(),
        source: source,
        injested_at: timestamp,
        valid?: false
      }

      _ = RejectedLogEvents.injest(log_event)

      [rle] = RejectedLogEvents.get_by_source(source)

      assert rle.injested_at == timestamp
      assert rle.params == log_event.params
    end

    test "gets logs for all sources for user", %{users: [u1], sources: [s1, s2]} do
      source1 = Sources.get_by(token: s1.token)
      source2 = Sources.get_by(token: s2.token)
      user = Users.get_by(id: u1.id)

      validator = Logflare.Logs.Validators.EqDeepFieldTypes
      timestamp = System.system_time(:microsecond)

      log_event_1_source_1 = %LogEvent{
        body: %{
          message: "case1",
          metadata: %{
            "ip" => "0.0.0.0"
          },
          timestamp: timestamp
        },
        source: source1,
        valid?: false,
        validation_error: validator.message()
      }

      log_event_2_source_1 = %LogEvent{
        body: %{
          message: "case2",
          metadata: %{
            "ip" => "0.0.0.0"
          },
          timestamp: timestamp
        },
        source: source1,
        valid?: false,
        validation_error: validator.message()
      }

      log_event_1_source_2 = %LogEvent{
        body: %{
          message: "case2",
          metadata: %{
            "ip" => "0.0.0.0"
          },
          timestamp: timestamp
        },
        source: source2,
        valid?: false,
        validation_error: validator.message()
      }

      _ = RejectedLogEvents.injest(log_event_1_source_1)
      _ = RejectedLogEvents.injest(log_event_2_source_1)
      _ = RejectedLogEvents.injest(log_event_1_source_2)

      result = RejectedLogEvents.get_by_user(user)

      assert map_size(result) == 2

      assert [
               %LogEvent{validation_error: validator_message, body: _, params: _, injested_at: _},
               %LogEvent{validation_error: validator_message, body: _, params: _, injested_at: _}
             ] = result[source1.token]

      assert [
               %LogEvent{
                 validation_error: validator_message,
                 body: _,
                 params: _,
                 injested_at: _
               }
             ] = result[source2.token]
    end
  end
end
