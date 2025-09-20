# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2024, by Samuel Williams.

require "covered/sus"
include Covered::Sus

ENV["TRACES_BACKEND"] ||= "traces/backend/test"
ENV["METRICS_BACKEND"] ||= "metrics/backend/test"

def prepare_instrumentation!
	require "traces"
	require "metrics"
	
	# Enable coverage of all tracing:
	Traces.trace_context = Traces::Context.local
end

def before_tests(...)
	prepare_instrumentation!
	
	super
end
