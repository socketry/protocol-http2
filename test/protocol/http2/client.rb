# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require "protocol/http2/connection_context"

describe Protocol::HTTP2::Client do
	include_context Protocol::HTTP2::ConnectionContext
	
	let(:framer) {server.framer}
	
	let(:settings) do
		[[Protocol::HTTP2::Settings::HEADER_TABLE_SIZE, 1024]]
	end
	
	it "has an id of 0" do
		expect(client.id).to be == 0
		expect(client[0]).to be == client
	end
	
	it "can lookup stream by id" do
		stream = client.create_stream
		expect(client[stream.id]).to be == stream
	end
	
	it "should start in new state" do
		expect(client.state).to be == :new
	end
	
	it "should send connection preface followed by settings frame" do
		client.send_connection_preface(settings) do
			expect(framer.read_connection_preface).to be == Protocol::HTTP2::CONNECTION_PREFACE
			
			client_settings_frame = framer.read_frame
			expect(client_settings_frame).to be_a Protocol::HTTP2::SettingsFrame
			expect(client_settings_frame.unpack).to be == settings
			
			# Fake (empty) server settings:
			server_settings_frame = Protocol::HTTP2::SettingsFrame.new
			server_settings_frame.pack
			framer.write_frame(server_settings_frame)
			
			framer.write_frame(client_settings_frame.acknowledge)
		end
		
		expect(client.state).to be == :new
		
		client.read_frame
		
		expect(client.state).to be == :open
		expect(client.local_settings.header_table_size).to be == 1024
	end
	
	it "should fail if the server does not reply with settings frame" do
		data_frame = Protocol::HTTP2::DataFrame.new
		data_frame.pack("Hello, World!")
		
		expect do
			client.send_connection_preface(settings) do
				framer.write_frame(data_frame)
			end
		end.to raise_exception(Protocol::HTTP2::ProtocolError, message: be =~ /First frame must be Protocol::HTTP2::SettingsFrame/)
	end
	
	it "can generate a stream id" do
		id = client.next_stream_id
		expect(id).to be == 1
		
		expect(client).to be(:local_stream_id?, id)
		expect(client).not.to be(:remote_stream_id?, id)
	end
	
	it "can't send connection preface in open state" do
		client.open!
		
		expect do
			client.send_connection_preface(settings)
		end.to raise_exception(Protocol::HTTP2::ProtocolError)
	end
	
	it "can't generate push promise stream" do
		expect do
			client.create_push_promise_stream
		end.to raise_exception(Protocol::HTTP2::ProtocolError)
	end
	
	it "can't receive push promise stream for stream id 0" do
		frame = Protocol::HTTP2::PushPromiseFrame.new
		frame.pack(0, "Hello World")
		
		expect do
			client.receive_push_promise(frame)
		end.to raise_exception(Protocol::HTTP2::ProtocolError)
	end
end
