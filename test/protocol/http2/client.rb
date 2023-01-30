# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require_relative 'connection_context'

RSpec.describe Protocol::HTTP2::Client do
	include_context Protocol::HTTP2::Connection
	
	let(:framer) {server.framer}
	
	let(:settings) do
		[[Protocol::HTTP2::Settings::HEADER_TABLE_SIZE, 1024]]
	end
	
	it "should start in new state" do
		expect(client.state).to eq :new
	end
	
	it "should send connection preface followed by settings frame" do
		client.send_connection_preface(settings) do
			expect(framer.read_connection_preface).to eq Protocol::HTTP2::CONNECTION_PREFACE_MAGIC
			
			client_settings_frame = framer.read_frame
			expect(client_settings_frame).to be_kind_of Protocol::HTTP2::SettingsFrame
			expect(client_settings_frame.unpack).to eq settings
			
			# Fake (empty) server settings:
			server_settings_frame = Protocol::HTTP2::SettingsFrame.new
			server_settings_frame.pack
			framer.write_frame(server_settings_frame)
			
			framer.write_frame(client_settings_frame.acknowledge)
		end
		
		expect(client.state).to eq :new
		
		client.read_frame
		
		expect(client.state).to eq :open
		expect(client.local_settings.header_table_size).to eq 1024
	end
end
