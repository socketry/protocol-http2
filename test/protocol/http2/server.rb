# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require_relative 'connection_context'

RSpec.describe Protocol::HTTP2::Client do
	include_context Protocol::HTTP2::Connection
	
	let(:framer) {client.framer}
	
	let(:client_settings) do
		[[Protocol::HTTP2::Settings::HEADER_TABLE_SIZE, 1024]]
	end
	
	let(:server_settings) do
		[[Protocol::HTTP2::Settings::HEADER_TABLE_SIZE, 2048]]
	end
	
	it "should start in new state" do
		expect(server.state).to eq :new
	end
	
	it "should receive connection preface followed by settings frame" do
		# The client must write the connection preface followed immediately by the first settings frame:
		framer.write_connection_preface
		
		settings_frame = Protocol::HTTP2::SettingsFrame.new
		settings_frame.pack(client_settings)
		framer.write_frame(settings_frame)
		
		expect(server.state).to eq :new
		
		# The server should read the preface and settings...
		server.read_connection_preface(server_settings)
		expect(server.remote_settings.header_table_size).to eq 1024
		
		# The server immediately sends its own settings frame...
		frame = framer.read_frame
		expect(frame).to be_kind_of Protocol::HTTP2::SettingsFrame
		expect(frame.unpack).to eq server_settings
		
		# And then it acknowledges the client settings:
		frame = framer.read_frame
		expect(frame).to be_kind_of Protocol::HTTP2::SettingsFrame
		expect(frame).to be_acknowledgement
		
		# We reply with acknolwedgement:
		framer.write_frame(frame.acknowledge)
		
		server.read_frame
		
		expect(server.state).to eq :open
	end
end
