# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require "protocol/http2/push_promise_frame"
require "protocol/http2/connection_context"
require "protocol/http2/a_frame"

describe Protocol::HTTP2::PushPromiseFrame do
	let(:stream_id) {5}
	let(:data) {"Hello World!"}
	let(:frame) {subject.new}
	
	it_behaves_like Protocol::HTTP2::AFrame do
		def before
			frame.set_flags(Protocol::HTTP2::END_HEADERS)
			frame.pack stream_id, data
			
			super
		end
	end
	
	with "#pack" do
		it "packs stream_id and data with padding" do
			frame.pack stream_id, data
			
			expect(frame.padded?).to be_falsey
			expect(frame.length).to be == 16
		end
	end
	
	with "#unpack" do
		it "unpacks stream_id and data" do
			frame.pack stream_id, data
			
			expect(frame.unpack).to be == [stream_id, data]
		end
	end
	
	with "client/server connection" do
		include_context Protocol::HTTP2::ConnectionContext
		
		def before
			client.open!
			server.open!
			
			super
		end
		
		let(:stream) {client.create_stream}
		
		let(:request_headers) do
			[[":method", "GET"], [":authority", "Earth"], [":path", "/index.html"]]
		end
		
		let(:push_promise_headers) do
			[[":method", "GET"], [":authority", "Earth"], [":path", "/index.css"]]
		end
		
		it "sends push promise to client" do
			# Client sends a request:
			stream.send_headers(request_headers)
			
			# Server receives request:
			expect(server.read_frame).to be_a Protocol::HTTP2::HeadersFrame
			
			# Get the request stream on the server:
			server_stream = server.streams[stream.id]
			
			# Push a promise back through the stream:
			promised_stream = server_stream.send_push_promise(push_promise_headers)
			
			expect(client).to receive(:receive_push_promise) do |frame|
				stream, headers = super(frame)
				
				expect(stream.id).to be == promised_stream.id
				expect(headers).to be == push_promise_headers
			end
			
			expect(client.read_frame).to be_a Protocol::HTTP2::PushPromiseFrame
		end
		
		it "fails if the same push promise is sent twice" do
			# Client sends a request:
			stream.send_headers(request_headers)
			
			# Server receives request:
			expect(server.read_frame).to be_a Protocol::HTTP2::HeadersFrame
			
			# Get the request stream on the server:
			server_stream = server.streams[stream.id]
			
			# Push a promise back through the stream:
			promised_stream = server_stream.send_push_promise(push_promise_headers)
			
			push_promise_frame = client.read_frame
			expect(push_promise_frame).to be_a Protocol::HTTP2::PushPromiseFrame
			
			# Force the stream to be sent a 2nd time:
			expect do
				push_promise_frame.apply(client)
			end.to raise_exception(Protocol::HTTP2::Error)
		end
	end
end
