# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'protocol/http2/headers_frame'

require_relative 'connection_context'
require_relative 'frame_examples'

RSpec.describe Protocol::HTTP2::HeadersFrame do
	let(:priority) {Protocol::HTTP2::Priority.new(true, 42, 7)}
	let(:data) {"Hello World!"}
	
	it_behaves_like Protocol::HTTP2::Frame do
		before do
			subject.set_flags(Protocol::HTTP2::END_HEADERS)
			subject.pack priority, data
		end
	end
	
	describe '#pack' do
		it "adds appropriate padding" do
			subject.pack nil, data
			
			expect(subject.length).to be == 12
			expect(subject).to_not be_priority
		end
		
		it "packs priority with no padding" do
			subject.pack priority, data
			
			expect(priority.pack.size).to be == 5
			expect(subject.length).to be == (5 + data.bytesize)
		end
	end
	
	describe '#unpack' do
		it "removes padding" do
			subject.pack nil, data
			
			expect(subject.unpack).to be == [nil, data]
		end
	end
	
	describe '#continuation' do
		it "generates chain of frames" do
			subject.pack nil, "Hello World", maximum_size: 8
			
			expect(subject.length).to eq 8
			expect(subject.continuation).to_not be_nil
			expect(subject.continuation.length).to eq 3
		end
	end
	
	context "client/server connection" do
		include_context Protocol::HTTP2::Connection
		
		before do
			client.open!
			server.open!
			
			# We force this to something low so we can exceed it without hitting the socket buffer:
			server.local_settings.current.instance_variable_set(:@maximum_frame_size, 128)
		end
		
		let(:stream) {client.create_stream}
		
		it "rejects headers frame that exceeds maximum frame size" do
			subject.stream_id = stream.id
			subject.pack nil, "\0" * (server.local_settings.maximum_frame_size + 1)
			
			client.write_frame(subject)
			
			expect do
				server.read_frame
			end.to raise_error(Protocol::HTTP2::FrameSizeError)
			
			expect(client).to receive(:receive_goaway).once.and_call_original
			
			expect do
				client.read_frame
			end.to raise_error(Protocol::HTTP2::GoawayError)
		end
	end
end
