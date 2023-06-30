# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require 'protocol/http2/settings_frame'

describe Protocol::HTTP2::Settings do
	let(:settings) {subject.new}
	
	with '#enable_push' do
		it "is enabled by default" do
			expect(settings.enable_push).to be == 1
			expect(settings).to be(:enable_push?)
		end
		
		it "can be disabled" do
			settings.enable_push = 0
			expect(settings.enable_push).to be == 0
			expect(settings).not.to be(:enable_push?)
		end
		
		it "only accepts valid values" do
			expect{settings.enable_push = 2}.to raise_exception(Protocol::HTTP2::ProtocolError)
		end
	end
	
	with '#initial_window_size' do
		it "is 65535 by default" do
			expect(settings.initial_window_size).to be == 0xFFFF
		end
		
		it "can be updated" do
			settings.initial_window_size = 1000
			expect(settings.initial_window_size).to be == 1000
		end
		
		it "only accepts valid values" do
			expect{settings.initial_window_size = (Protocol::HTTP2::MAXIMUM_ALLOWED_WINDOW_SIZE + 1)}.to raise_exception(Protocol::HTTP2::ProtocolError)
		end
	end
	
	with '#maximum_frame_size' do
		it "is 16384 by default" do
			expect(settings.maximum_frame_size).to be == 0x4000
		end
		
		it "can be updated" do
			settings.maximum_frame_size = 20000
			expect(settings.maximum_frame_size).to be == 20000
		end
		
		it "only accepts valid values" do
			expect{settings.maximum_frame_size = (Protocol::HTTP2::MAXIMUM_ALLOWED_FRAME_SIZE + 1)}.to raise_exception(Protocol::HTTP2::ProtocolError)
			expect{settings.maximum_frame_size = (Protocol::HTTP2::MINIMUM_ALLOWED_FRAME_SIZE - 1)}.to raise_exception(Protocol::HTTP2::ProtocolError)
		end
	end
	
	with '#enable_connect_protocol' do
		it "is disabled by default" do
			expect(settings.enable_connect_protocol).to be == 0
			expect(settings).not.to be(:enable_connect_protocol?)
		end
		
		it "can be enabled" do
			settings.enable_connect_protocol = 1
			expect(settings.enable_connect_protocol).to be == 1
			expect(settings).to be(:enable_connect_protocol?)
		end
		
		it "only accepts valid values" do
			expect{settings.enable_connect_protocol = 2}.to raise_exception(Protocol::HTTP2::ProtocolError)
		end
	end
	
	it "has the expected defaults" do
		expect(settings).to have_attributes(
			header_table_size: be == 4096,
			enable_push: be == 1,
			maximum_concurrent_streams: be == 0xFFFFFFFF,
			initial_window_size: be == 0xFFFF,
			maximum_frame_size: be == 0x4000,
			maximum_header_list_size: be == 0xFFFFFFFF,
			enable_connect_protocol: be == 0
		)
	end
	
	it "can be updated" do
		settings.update({
			Protocol::HTTP2::Settings::HEADER_TABLE_SIZE => 100,
			Protocol::HTTP2::Settings::ENABLE_PUSH => 0,
			Protocol::HTTP2::Settings::MAXIMUM_CONCURRENT_STREAMS => 10,
			Protocol::HTTP2::Settings::INITIAL_WINDOW_SIZE => 1000,
			Protocol::HTTP2::Settings::MAXIMUM_FRAME_SIZE => 20000,
			Protocol::HTTP2::Settings::MAXIMUM_HEADER_LIST_SIZE => 100000,
			Protocol::HTTP2::Settings::ENABLE_CONNECT_PROTOCOL => 1
		})
		
		expect(settings).to have_attributes(
			header_table_size: be == 100,
			enable_push: be == 0,
			maximum_concurrent_streams: be == 10,
			initial_window_size: be == 1000,
			maximum_frame_size: be == 20000,
			maximum_header_list_size: be == 100000,
			enable_connect_protocol: be == 1
		)
	end
	
	it "can compute the difference between two settings" do
		other = subject.new
		other.update({
			Protocol::HTTP2::Settings::HEADER_TABLE_SIZE => 100,
			Protocol::HTTP2::Settings::ENABLE_PUSH => 0,
			Protocol::HTTP2::Settings::MAXIMUM_CONCURRENT_STREAMS => 10,
			Protocol::HTTP2::Settings::INITIAL_WINDOW_SIZE => 1000,
			Protocol::HTTP2::Settings::MAXIMUM_FRAME_SIZE => 20000,
			Protocol::HTTP2::Settings::MAXIMUM_HEADER_LIST_SIZE => 100000,
			Protocol::HTTP2::Settings::ENABLE_CONNECT_PROTOCOL => 1
		})
		
		expect(other.difference(settings)).to be == [
			[Protocol::HTTP2::Settings::HEADER_TABLE_SIZE, 100],
			[Protocol::HTTP2::Settings::ENABLE_PUSH, 0],
			[Protocol::HTTP2::Settings::MAXIMUM_CONCURRENT_STREAMS, 10],
			[Protocol::HTTP2::Settings::INITIAL_WINDOW_SIZE, 1000],
			[Protocol::HTTP2::Settings::MAXIMUM_FRAME_SIZE, 20000],
			[Protocol::HTTP2::Settings::MAXIMUM_HEADER_LIST_SIZE, 100000],
			[Protocol::HTTP2::Settings::ENABLE_CONNECT_PROTOCOL, 1]
		]
	end
end

describe Protocol::HTTP2::PendingSettings do
	let(:pending_settings) {subject.new}
	
	it "has the expected defaults" do
		expect(pending_settings).to have_attributes(
			header_table_size: be == 4096,
			enable_push: be == 1,
			maximum_concurrent_streams: be == 0xFFFFFFFF,
			initial_window_size: be == 0xFFFF,
			maximum_frame_size: be == 0x4000,
			maximum_header_list_size: be == 0xFFFFFFFF,
			enable_connect_protocol: be == 0
		)
	end
	
	it "can append changes" do
		pending_settings.append([
			[Protocol::HTTP2::Settings::HEADER_TABLE_SIZE, 100],
			[Protocol::HTTP2::Settings::ENABLE_PUSH, 0],
		])
		
		expect(pending_settings).to have_attributes(
			header_table_size: be == 4096,
			enable_push: be == 1
		)
		
		pending_settings.acknowledge
		
		expect(pending_settings).to have_attributes(
			header_table_size: be == 100,
			enable_push: be == 0
		)
	end
	
	it "can't acknowledge changes that haven't been appended" do
		expect{pending_settings.acknowledge}.to raise_exception(Protocol::HTTP2::ProtocolError)
	end
	
	it "can't acknowledge changes that have already been acknowledged" do
		pending_settings.append([
			[Protocol::HTTP2::Settings::HEADER_TABLE_SIZE, 100],
			[Protocol::HTTP2::Settings::ENABLE_PUSH, 0],
		])
		
		pending_settings.acknowledge
		
		expect{pending_settings.acknowledge}.to raise_exception(Protocol::HTTP2::ProtocolError)
	end
end
