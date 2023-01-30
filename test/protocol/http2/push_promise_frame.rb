# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'protocol/http2/push_promise_frame'
require_relative 'connection_context'
require_relative 'frame_examples'

RSpec.describe Protocol::HTTP2::PushPromiseFrame do
	let(:stream_id) {5}
	let(:data) {"Hello World!"}
	
	it_behaves_like Protocol::HTTP2::Frame do
		before do
			subject.set_flags(Protocol::HTTP2::END_HEADERS)
			subject.pack stream_id, data
		end
	end
	
	describe '#pack' do
		it "packs stream_id and data with padding" do
			subject.pack stream_id, data
			
			expect(subject.padded?).to be_falsey
			expect(subject.length).to be == 16
		end
	end
	
	describe '#unpack' do
		it "unpacks stream_id and data" do
			subject.pack stream_id, data
			
			expect(subject.unpack).to be == [stream_id, data]
		end
	end
	
	context "client/server connection" do
		include_context Protocol::HTTP2::Connection
		
		before do
			client.open!
			server.open!
		end
		
		let(:stream) {client.create_stream}
		
		let(:request_headers) do
			[[':method', 'GET'], [':authority', 'Earth'], [':path', '/index.html']]
		end
		
		let(:push_promise_headers) do
			[[':method', 'GET'], [':authority', 'Earth'], [':path', '/index.css']]
		end
		
		it "sends push promise to client" do
			# Client sends a request:
			stream.send_headers(nil, request_headers)
			
			# Server receives request:
			expect(server.read_frame).to be_kind_of Protocol::HTTP2::HeadersFrame
			
			# Get the request stream on the server:
			server_stream = server.streams[stream.id]
			
			# Push a promise back through the stream:
			promised_stream = server_stream.send_push_promise(push_promise_headers)
			
			expect(client).to receive(:receive_push_promise).and_wrap_original do |m, *args| stream, headers = m.call(*args)
				
				expect(stream.id).to be == promised_stream.id
				expect(headers).to be == push_promise_headers
			end
			
			expect(client.read_frame).to be_kind_of Protocol::HTTP2::PushPromiseFrame
		end
	end
end
