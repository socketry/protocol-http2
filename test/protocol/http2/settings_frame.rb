# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'protocol/http2/settings_frame'
require 'frame_examples'

describe Protocol::HTTP2::SettingsFrame do
	let(:settings) {[
		[3, 10], [5, 1048576], [4, 2147483647], [8, 1]
	]}
	let(:frame) {subject.new}
	
	it_behaves_like FrameExamples do
		def before
			frame.pack settings
			
			super
		end
	end
	
	with '#pack' do
		it "packs settings" do
			frame.pack settings
			
			expect(frame.length).to be == 6*settings.size
		end
	end
	
	with '#unpack' do
		it "unpacks settings" do
			frame.pack settings
			
			expect(frame.unpack).to be == settings
		end
	end
end
