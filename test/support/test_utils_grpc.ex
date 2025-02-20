defmodule Logflare.TestUtilsGrpc do
  alias Logflare.TestUtils

  alias Opentelemetry.Proto.Collector.Trace.V1.ExportTraceServiceRequest
  alias Opentelemetry.Proto.Common.V1.AnyValue
  alias Opentelemetry.Proto.Common.V1.InstrumentationScope
  alias Opentelemetry.Proto.Common.V1.KeyValue
  alias Opentelemetry.Proto.Resource.V1.Resource
  alias Opentelemetry.Proto.Trace.V1.ScopeSpans
  alias Opentelemetry.Proto.Trace.V1.Span
  alias Opentelemetry.Proto.Trace.V1.Span.Event

  @doc """
  Generates a ExportTraceServiceRequest message which contains a Span and an Event in it
  """
  def random_export_service_request do
    ExportTraceServiceRequest.new(resource_spans: random_resource_span())
  end

  @doc """
  Generates a single ResourceSpan message which contains a Span and an Event in it
  """
  def random_resource_span do
    [
      Opentelemetry.Proto.Trace.V1.ResourceSpans.new(
        resource: Resource.new(),
        scope_spans: random_scope_span()
      )
    ]
  end

  defp random_scope_span do
    scope =
      InstrumentationScope.new(
        name: TestUtils.random_string(),
        version: TestUtils.random_string(),
        attributes: random_attributes()
      )

    [ScopeSpans.new(scope: scope, spans: random_span())]
  end

  defp random_span do
    [
      Span.new(
        name: TestUtils.random_string(),
        span_id: :crypto.strong_rand_bytes(8),
        parent_span_id: :crypto.strong_rand_bytes(8),
        trace_id: :crypto.strong_rand_bytes(16),
        start_time_unix_nano: DateTime.utc_now() |> DateTime.to_unix(:nanosecond),
        end_time_unix_nano: DateTime.utc_now() |> DateTime.to_unix(:nanosecond),
        events: random_event()
      )
    ]
  end

  defp random_event do
    [
      Event.new(
        name: TestUtils.random_string(),
        time_unix_nano: DateTime.utc_now() |> DateTime.to_unix(:nanosecond)
      )
    ]
  end

  defp random_attributes do
    string = random_key_value(:string)
    boolean = random_key_value(:boolean)
    integer = random_key_value(:integer)
    double = random_key_value(:double)

    [string, boolean, integer, double]
  end

  defp random_key_value(:string) do
    KeyValue.new(
      key: "random_string_#{TestUtils.random_string()}",
      value: AnyValue.new(value: {:string_value, TestUtils.random_string()})
    )
  end

  defp random_key_value(:boolean) do
    KeyValue.new(
      key: "random_boolean_#{TestUtils.random_string()}",
      value: AnyValue.new(value: {:bool_value, Enum.random([true, false])})
    )
  end

  defp random_key_value(:integer) do
    KeyValue.new(
      key: "random_integer_#{TestUtils.random_string()}",
      value: AnyValue.new(value: {:int_value, :rand.uniform(100)})
    )
  end

  defp random_key_value(:double) do
    KeyValue.new(
      key: "random_double_#{TestUtils.random_string()}",
      value: AnyValue.new(value: {:double_value, :rand.uniform(100) + 1.00})
    )
  end
end
