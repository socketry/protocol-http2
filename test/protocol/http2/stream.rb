# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'connection_context'

describe Protocol::HTTP2::Stream do
	include_context ConnectionContext
	
	def before
		client.open!
		server.open!
		
		super
	end
	
	with "idle stream" do
		let(:stream) {client.create_stream}
		
		it "is not active" do
			expect(stream).not.to be(:active?)
		end
		
		it "can send headers" do
			expect(stream).to be(:send_headers?)
		end
		
		it "can't receive stream reset" do
			frame = Protocol::HTTP2::ResetStreamFrame.new(stream.id)
			
			expect do
				stream.receive_reset_stream(frame)
			end.to raise_exception(Protocol::HTTP2::ProtocolError, message: be =~ /Cannot receive reset stream/)
		end
		
		it "can inspect the stream" do
			expect(stream.inspect).to be =~ /id=1 state=idle/
		end
		
		it "can send headers" do
			stream.send_headers(nil, [["foo", "bar"]])
			
			server_stream = server.create_stream(stream.id)
			
			expect(server_stream).to receive(:receive_headers)
			
			server.read_frame
		end
		
		it "cannot send data" do
			expect do
				stream.send_data("Hello World!")
			end.to raise_exception(Protocol::HTTP2::ProtocolError, message: be =~ /Cannot send data in state: idle/)
		end
		
		it "cannot send reset stream" do
			expect do
				stream.send_reset_stream
			end.to raise_exception(Protocol::HTTP2::ProtocolError, message: be =~ /Cannot send reset stream/)
		end
		
		it "cannot receive data" do
			stream.open!
			stream.send_data("Hello World!")
			
			expect do
				server.read_frame
			end.to raise_exception(Protocol::HTTP2::ProtocolError, message: be =~ /Cannot receive data/)
		end
		
		it "cannot receive stream reset" do
			stream.open!
			stream.send_reset_stream
			
			expect do
				server.read_frame
			end.to raise_exception(Protocol::HTTP2::ProtocolError, message: be =~ /Cannot reset stream/)
		end
	end
	
	with "open stream" do
		let(:stream) {client.create_stream.open!}
		
		it "is active" do
			expect(stream).to be(:active?)
		end
		
		it "can send headers" do
			expect(stream).to be(:send_headers?)
		end
		
		it "can send data" do
			stream.send_data("Hello World!")
			
			server_stream = server.create_stream(stream.id)
			
			expect(server_stream).to receive(:receive_data).and_return(nil)
			
			server.read_frame
		end
		
		it "can send reset stream" do
			stream.send_reset_stream
			
			server_stream = server.create_stream(stream.id)
			
			expect(server_stream).to receive(:receive_reset_stream).and_return(nil)
			
			server.read_frame
		end
	end
	
	with "closed stream" do
		let(:stream) {client.create_stream.close!}
		
		it "is not active" do
			expect(stream).not.to be(:active?)
		end
		
		it "can't send headers" do
			expect(stream).not.to be(:send_headers?)
		end
		
		it "cannot send reset stream" do
			expect do
				stream.send_reset_stream
			end.to raise_exception(Protocol::HTTP2::ProtocolError, message: be =~ /Cannot send reset stream/)
		end
		
		it "cannot reserve local" do
			expect do
				stream.reserved_local!
			end.to raise_exception(Protocol::HTTP2::ProtocolError, message: be =~ /Cannot reserve stream/)
		end
		
		it "cannot reserve remote" do
			expect do
				stream.reserved_remote!
			end.to raise_exception(Protocol::HTTP2::ProtocolError, message: be =~ /Cannot reserve stream/)
		end
		
		it "cannot send push promise" do
			expect do
				stream.send_push_promise([])
			end.to raise_exception(Protocol::HTTP2::ProtocolError, message: be =~ /Cannot send push promise/)
		end
		
		it "ignores headers" do
			expect(stream).to receive(:ignore_headers)
			
			stream.receive_headers(nil)
		end
		
		it "ignores data" do
			expect(stream).to receive(:ignore_data)
			
			stream.receive_data(nil)
		end
		
		it "ignores reset stream" do
			server_stream = server.create_stream(stream.id)
			server_stream.open!
			server_stream.send_reset_stream
			
			client.read_frame
		end
	end
end
