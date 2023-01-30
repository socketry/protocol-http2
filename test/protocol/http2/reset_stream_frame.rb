# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'protocol/http2/reset_stream_frame'
require_relative 'frame_examples'

RSpec.describe Protocol::HTTP2::ResetStreamFrame do
	let(:error) {Protocol::HTTP2::INTERNAL_ERROR}
	
	it_behaves_like Protocol::HTTP2::Frame do
		before do
			subject.pack error
		end
	end
	
	describe '#pack' do
		it "packs error" do
			subject.pack error
			expect(subject.length).to be == 4
		end
	end
	
	describe '#unpack' do
		it "unpacks error" do
			subject.pack error
			expect(subject.unpack).to be == error
		end
	end
end
