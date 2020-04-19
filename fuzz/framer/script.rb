#!/usr/bin/env ruby

require 'socket'
require_relative '../../lib/protocol/http2/framer'

def test
	framer = Protocol::HTTP2::Framer.new($stdin)
	
	while frame = framer.read_frame
		pp frame
	end
rescue EOFError
	# Ignore.
end

if ENV["_"] =~ /afl/
	require 'kisaten'
	
	Kisaten.crash_at [Exception], [EOFError, Protocol::HTTP2::FrameSizeError], Signal.list['USR1']
	
	while Kisaten.loop 10_000
		test
	end
else
	test
end
