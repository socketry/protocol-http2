# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'protocol/http2/settings_frame'
require_relative 'frame_examples'

RSpec.describe Protocol::HTTP2::SettingsFrame do
	let(:settings) {[
		[3, 10], [5, 1048576], [4, 2147483647], [8, 1]
	]}
	
	it_behaves_like Protocol::HTTP2::Frame do
		before do
			subject.pack settings
		end
	end
	
	describe '#pack' do
		it "packs settings" do
			subject.pack settings
			
			expect(subject.length).to be == 6*settings.size
		end
	end
	
	describe '#unpack' do
		it "unpacks settings" do
			subject.pack settings
			
			expect(subject.unpack).to be == settings
		end
	end
end
