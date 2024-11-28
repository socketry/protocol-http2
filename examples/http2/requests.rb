# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require "async"
require "async/io/stream"
require "async/http/endpoint"
require "protocol/http2/client"

queries = ["apple", "orange", "teapot", "async"]

Async do
	endpoint = Async::HTTP::Endpoint.parse("https://www.google.com")
	
	peer = endpoint.connect
	stream = Async::IO::Stream.new(peer)
	framer = Protocol::HTTP2::Framer.new(stream)
	client = Protocol::HTTP2::Client.new(framer)
	
	puts "Sending connection preface..."
	client.send_connection_preface
	
	puts "Creating stream..."
	streams = queries.collect do |keyword|
		client.create_stream.tap do |stream|
			headers = [
				[":scheme", endpoint.scheme],
				[":method", "GET"],
				[":authority", "www.google.com"],
				[":path", "/search?q=#{keyword}"],
				["accept", "*/*"],
			]
			
			puts "Sending request on stream id=#{stream.id} state=#{stream.state}..."
			stream.send_headers(headers, Protocol::HTTP2::END_STREAM)
		
			def stream.process_headers(frame)
				headers = super
				puts "Stream #{self.id}: Got response headers: #{headers} (#{frame.end_stream?})"
			end
			
			def stream.receive_data(frame)
				data = super
				puts "Stream #{self.id}: Got response data: #{data.bytesize}"
			end
		end
	end
	
	until streams.all?{|stream| stream.closed?}
		frame = client.read_frame
	end
	
	puts "Closing client..."
	client.close
end

puts "Exiting."
