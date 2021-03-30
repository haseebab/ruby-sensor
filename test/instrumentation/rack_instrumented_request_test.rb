# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class RackInstrumentedRequestTest < Minitest::Test
  def test_skip_trace_with_header
    req = Instana::InstrumentedRequest.new(
      'HTTP_X_INSTANA_L' => '0;sample-data'
    )

    assert req.skip_trace?
  end

  def test_skip_trace_without_header
    req = Instana::InstrumentedRequest.new({})

    refute req.skip_trace?
  end

  def test_incoming_context
    id = Instana::Util.generate_id
    req = Instana::InstrumentedRequest.new(
      'HTTP_X_INSTANA_L' => '1',
      'HTTP_X_INSTANA_T' => id,
      'HTTP_X_INSTANA_S' => id
    )

    expected = {
      trace_id: id,
      span_id: id,
      level: '1'
    }

    assert_equal expected, req.incoming_context
    refute req.continuing_from_trace_parent?
  end

  def test_incoming_w3_content
    req = Instana::InstrumentedRequest.new(
      'HTTP_X_INSTANA_L' => '1',
      'HTTP_TRACEPARENT' => '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01'
    )

    expected = {
      external_trace_id: '4bf92f3577b34da6a3ce929d0e0e4736',
      external_state: nil,
      trace_id: 'a3ce929d0e0e4736',
      span_id: '00f067aa0ba902b7',
      level: '1'
    }

    assert_equal expected, req.incoming_context
    assert req.continuing_from_trace_parent?
  end

  def test_incoming_invalid_w3_content
    req = Instana::InstrumentedRequest.new(
      'HTTP_X_INSTANA_L' => '1',
      'HTTP_TRACEPARENT' => '00-XXa3ce929d0e0e4736-00f67aa0ba902b7-01'
    )

    expected = {
      level: '1'
    }

    assert_equal expected, req.incoming_context
  end

  def test_incoming_w3_state
    req = Instana::InstrumentedRequest.new(
      'HTTP_TRACESTATE' => 'a=12345,in=123;abe,c=[+]'
    )

    expected = {
      t: '123',
      p: 'abe'
    }

    assert_equal expected, req.instana_ancestor
  end

  def test_request_tags
    ::Instana.agent.define_singleton_method(:extra_headers) { %w[X-Capture-This] }

    req = Instana::InstrumentedRequest.new(
      'HTTP_HOST' => 'example.com',
      'REQUEST_METHOD' => 'GET',
      'HTTP_X_CAPTURE_THIS' => 'that',
      'PATH_INFO' => '/',
      'QUERY_STRING' => 'test=true'
    )

    expected = {
      method: 'GET',
      url: '/',
      host: 'example.com',
      header: {
        "X-Capture-This": 'that'
      },
      params: 'test=true'
    }

    assert_equal expected, req.request_tags
    ::Instana.agent.singleton_class.send(:remove_method, :extra_headers)
  end

  def test_correlation_data_valid
    req = Instana::InstrumentedRequest.new(
      'HTTP_X_INSTANA_L' => '1,correlationType=web ;correlationId=1234567890abcdef'
    )
    expected = {
      type: 'web',
      id: '1234567890abcdef'
    }

    assert_equal expected, req.correlation_data
  end

  def test_correlation_data_invalid
    req = Instana::InstrumentedRequest.new(
      'HTTP_X_INSTANA_L' => '0;sample-data'
    )

    assert_equal({}, req.correlation_data)
  end

  def test_correlation_data_legacy
    req = Instana::InstrumentedRequest.new(
      'HTTP_X_INSTANA_L' => '1'
    )

    assert_equal({}, req.correlation_data)
  end
end
