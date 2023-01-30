# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'protocol/http2/window_update_frame'
require_relative 'frame_examples'

RSpec.describe Protocol::HTTP2::WindowUpdateFrame do
	let(:window_size_increment) {1024}
	
	it_behaves_like Protocol::HTTP2::Frame do
		before do
			subject.pack window_size_increment
		end
	end
	
	describe '#pack' do
		it "packs data" do
			subject.pack window_size_increment
			
			expect(subject.length).to be == 4
		end
	end
	
	describe '#unpack' do
		it "unpacks data" do
			subject.pack window_size_increment
			
			expect(subject.unpack).to be == window_size_increment
		end
	end
end
