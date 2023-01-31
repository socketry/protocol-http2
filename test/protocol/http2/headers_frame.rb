# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'protocol/http2/headers_frame'

require 'connection_context'
require 'frame_examples'

describe Protocol::HTTP2::HeadersFrame do
	let(:priority) {Protocol::HTTP2::Priority.new(true, 42, 7)}
	let(:data) {"Hello World!"}
	let(:frame) {subject.new}
	
	it_behaves_like FrameExamples do
		def before
			frame.set_flags(Protocol::HTTP2::END_HEADERS)
			frame.pack priority, data
			
			super
		end
	end
	
	with '#pack' do
		it "adds appropriate padding" do
			frame.pack nil, data
			
			expect(frame.length).to be == 12
			expect(frame).not.to be(:priority?)
		end
		
		it "packs priority with no padding" do
			frame.pack priority, data
			
			expect(priority.pack.size).to be == 5
			expect(frame.length).to be == (5 + data.bytesize)
		end
	end
	
	with '#unpack' do
		it "removes padding" do
			frame.pack nil, data
			
			expect(frame.unpack).to be == [nil, data]
		end
	end
	
	with '#continuation' do
		it "generates chain of frames" do
			frame.pack nil, "Hello World", maximum_size: 8
			
			expect(frame.length).to be == 8
			expect(frame.continuation).not.to be_nil
			expect(frame.continuation.length).to be == 3
		end
	end
	
	with "client/server connection" do
		include_context ConnectionContext
		
		def before
			client.open!
			server.open!
			
			# We force this to something low so we can exceed it without hitting the socket buffer:
			server.local_settings.current.instance_variable_set(:@maximum_frame_size, 128)
			
			super
		end
		
		let(:stream) {client.create_stream}
		
		it "rejects headers frame that exceeds maximum frame size" do
			frame.stream_id = stream.id
			frame.pack nil, "\0" * (server.local_settings.maximum_frame_size + 1)
			
			client.write_frame(frame)
			
			expect do
				server.read_frame
			end.to raise_exception(Protocol::HTTP2::FrameSizeError)
			
			expect(client).to receive(:receive_goaway)
			
			expect do
				client.read_frame
			end.to raise_exception(Protocol::HTTP2::GoawayError)
		end
	end
	
	with '#inspect' do
		it "can generate a string representation" do
			expect(frame.inspect).to be =~ /Protocol::HTTP2::HeadersFrame stream_id=0 flags=0 0b/
		end
	end
end
