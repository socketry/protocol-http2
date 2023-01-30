# Copyright, 2018, by Samuel G. D. Williams. <http: //www.codeotaku.com>
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

# Released under the MIT License.
# Copyright, 2019, by Samuel Williams.

# Released under the MIT License.
# Copyright, 2019, by Samuel Williams.

require 'protocol/http2/ping_frame'
require_relative 'frame_examples'

RSpec.describe Protocol::HTTP2::PingFrame do
	let(:data) {"PingPong"}
	
	it_behaves_like Protocol::HTTP2::Frame do
		before do
			subject.pack data
		end
	end
	
	describe '#pack' do
		it "packs data" do
			subject.pack data
			
			expect(subject.length).to be == 8
		end
	end
	
	describe '#unpack' do
		it "unpacks data" do
			subject.pack data
			
			expect(subject.unpack).to be == data
		end
	end
end
