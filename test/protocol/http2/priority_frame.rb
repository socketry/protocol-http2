# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'protocol/http2/priority_frame'
require_relative 'frame_examples'

RSpec.describe Protocol::HTTP2::PriorityFrame do
	let(:priority) {Protocol::HTTP2::Priority.new(true, 42, 7)}
	
	it_behaves_like Protocol::HTTP2::Frame do
		before do
			subject.pack priority
		end
	end
	
	describe '#pack' do
		it "packs priority" do
			subject.pack priority
			
			expect(subject.length).to be == 5
		end
	end
	
	describe '#unpack' do
		it "unpacks priority" do
			subject.pack priority
			
			expect(subject.unpack).to be == priority
		end
	end
end
