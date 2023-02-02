# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'connection_context'

describe Protocol::HTTP2::Client do
	include_context ConnectionContext
	
	let(:framer) {client.framer}
	
	let(:client_settings) do
		[[Protocol::HTTP2::Settings::HEADER_TABLE_SIZE, 1024]]
	end
	
	let(:server_settings) do
		[[Protocol::HTTP2::Settings::HEADER_TABLE_SIZE, 2048]]
	end
	
	it "has an id of 0" do
		expect(server.id).to be == 0
		expect(server[0]).to be == server
	end
	
	it "can lookup stream by id" do
		stream = server.create_stream
		expect(server[stream.id]).to be == stream
	end
	
	it "can optionally support push promises" do
		expect(server).to be(:enable_push?)
	end
	
	it "cannot accept push promises" do
		expect do
			server.accept_push_promise_stream(1)
		end.to raise_exception(Protocol::HTTP2::ProtocolError, message: be =~ /Cannot accept push promises/)
	end
	
	it "should start in new state" do
		expect(server.state).to be == :new
	end
	
	it "cannot read connection preface in open state" do
		server.open!
		expect do
			server.read_connection_preface
		end.to raise_exception(Protocol::HTTP2::ProtocolError, message: be =~ /Cannot read connection preface in state open/)
	end
	
	it "should receive connection preface followed by settings frame" do
		# The client must write the connection preface followed immediately by the first settings frame:
		framer.write_connection_preface
		
		settings_frame = Protocol::HTTP2::SettingsFrame.new
		settings_frame.pack(client_settings)
		framer.write_frame(settings_frame)
		
		expect(server.state).to be == :new
		
		# The server should read the preface and settings...
		server.read_connection_preface(server_settings)
		expect(server.remote_settings.header_table_size).to be == 1024
		
		# The server immediately sends its own settings frame...
		frame = framer.read_frame
		expect(frame).to be_a Protocol::HTTP2::SettingsFrame
		expect(frame.unpack).to be == server_settings
		
		# And then it acknowledges the client settings:
		frame = framer.read_frame
		expect(frame).to be_a Protocol::HTTP2::SettingsFrame
		expect(frame).to be(:acknowledgement?)
		
		# We reply with acknolwedgement:
		framer.write_frame(frame.acknowledge)
		
		server.read_frame
		
		expect(server.state).to be == :open
	end
	
	it "can generate a stream id" do
		id = server.next_stream_id
		expect(id).to be == 2
		
		expect(server).to be(:local_stream_id?, id)
		expect(server).not.to be(:remote_stream_id?, id)
	end
end
