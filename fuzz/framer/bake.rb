# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2024, by Samuel Williams.

# Run the fuzz test.
def run
	system("AFL_SKIP_BIN_CHECK=1 afl-fuzz -i input/ -o output/ -m 100 -- ruby script.rb")
end

def generate
	require_relative "../../lib/protocol/http2/framer"
	
	framer = Protocol::HTTP2::Framer.new($stdout)
	
	frame = Protocol::HTTP2::DataFrame.new
	frame.pack("Hello World")
	
	framer.write_frame(frame)
end
