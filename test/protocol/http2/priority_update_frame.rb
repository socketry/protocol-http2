# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2025, by Samuel Williams.

require "protocol/http2/priority_update_frame"

require "protocol/http2/a_frame"
require "protocol/http2/connection_context"

describe Protocol::HTTP2::PriorityUpdateFrame do
	let(:frame) {subject.new}
	
	it_behaves_like Protocol::HTTP2::AFrame do
		before do
			frame.pack 1, "u=1, i"
		end
		
		it "applies to the connection" do
			expect(frame).to be(:connection?)
		end
	end
	
	with "client/server connection" do
		include_context Protocol::HTTP2::ConnectionContext
		
		def before
			client.open!
			server.open!
			
			super
		end
		
		it "fails with protocol error if stream id is not zero" do
			# This isn't a valid for the frame stream_id:
			frame.stream_id = 1
			
			# This is a valid stream payload:
			frame.pack stream.id, "u=1, i"
			
			expect do
				frame.apply(server)
			end.to raise_exception(Protocol::HTTP2::ProtocolError)
		end
		
		let(:stream) {client.create_stream}
		
		it "updates the priority of a stream" do
			stream.send_headers [["content-type", "text/plain"]]
			server.read_frame
			
			expect(server).to receive(:receive_priority_update)
			expect(stream.priority).to be_nil
			
			frame.pack stream.id, "u=1, i"
			client.write_frame(frame)
			
			inform server.read_frame
			
			server_stream = server.streams[stream.id]
			expect(server_stream).not.to be_nil
			
			expect(server_stream.priority).to be == ["u=1", "i"]
		end
	end
end
