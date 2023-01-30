# Copyright, 2018, by Samuel G. D. Williams. <http: //www.codeotaku.com>
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

# Released under the MIT License.
# Copyright, 2019-2020, by Samuel Williams.

# Released under the MIT License.
# Copyright, 2019-2020, by Samuel Williams.

require_relative 'connection_context'

RSpec.describe Protocol::HTTP2::Stream do
	include_context Protocol::HTTP2::Connection
	
	before do
		client.open!
		server.open!
	end
	
	context "idle stream" do
		let(:stream) {client.create_stream}
		
		it "can send headers" do
			stream.send_headers(nil, [["foo", "bar"]])
			
			server_stream = server.create_stream(stream.id)
			
			expect(server_stream).to receive(:receive_headers)
			
			server.read_frame
		end
		
		it "cannot send data" do
			expect do
				stream.send_data("Hello World!")
			end.to raise_error(Protocol::HTTP2::ProtocolError, /Cannot send data in state: idle/)
		end
		
		it "cannot send reset stream" do
			expect do
				stream.send_reset_stream
			end.to raise_error(Protocol::HTTP2::ProtocolError, /Cannot send reset stream/)
		end
		
		it "cannot receive data" do
			stream.open!
			stream.send_data("Hello World!")
			
			expect do
				server.read_frame
			end.to raise_error(Protocol::HTTP2::ProtocolError, /Cannot receive data/)
		end
		
		it "cannot receive stream reset" do
			stream.open!
			stream.send_reset_stream
			
			expect do
				server.read_frame
			end.to raise_error(Protocol::HTTP2::ProtocolError, /Cannot reset stream/)
		end
	end
	
	context "open stream" do
		let(:stream) {client.create_stream.open!}
		
		it "can send data" do
			stream.send_data("Hello World!")
			
			server_stream = server.create_stream(stream.id)
			
			expect(server_stream).to receive(:receive_data)
			
			server.read_frame
		end
		
		it "can send reset stream" do
			stream.send_reset_stream
			
			server_stream = server.create_stream(stream.id)
			
			expect(server_stream).to receive(:receive_reset_stream)
			
			server.read_frame
		end
	end
	
	context "closed stream" do
		let(:stream) {client.create_stream.close!}
		
		it "cannot send reset stream" do
			expect do
				stream.send_reset_stream
			end.to raise_error(Protocol::HTTP2::ProtocolError, /Cannot send reset stream/)
		end
		
		it "ignores headers" do
			expect(stream).to receive(:ignore_headers)
			
			stream.receive_headers(double)
		end
		
		it "ignores data" do
			expect(stream).to receive(:ignore_data)
			
			stream.receive_data(double)
		end
		
		it "ignores reset stream" do
			server_stream = server.create_stream(stream.id)
			server_stream.open!
			server_stream.send_reset_stream
			
			client.read_frame
		end
	end
end
