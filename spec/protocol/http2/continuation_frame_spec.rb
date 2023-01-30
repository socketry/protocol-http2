# Copyright, 2018, by Samuel G. D. Williams. <http: //www.codeotaku.com>
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

# Released under the MIT License.
# Copyright, 2019, by Samuel Williams.

# Released under the MIT License.
# Copyright, 2019, by Samuel Williams.

require 'protocol/http2/continuation_frame'
require_relative 'frame_examples'

RSpec.describe Protocol::HTTP2::ContinuationFrame do
	let(:data) {"Hello World!"}
	
	it_behaves_like Protocol::HTTP2::Frame do
		before do
			subject.pack data
		end
	end
	
	describe '#pack' do
		it "packs data" do
			subject.pack data
			
			expect(subject.length).to be == data.bytesize
		end
		
		it "packs data over multiple continuation frames" do
			subject.pack data, maximum_size: 6
			
			expect(subject.continuation).to_not be_nil
		end
	end
	
	describe '#unpack' do
		it "unpacks data" do
			subject.pack data
			
			expect(subject.unpack).to be == data
		end
		
		it "unpacks data over multiple continuations" do
			subject.pack data, maximum_size: 2
			
			expect(subject.unpack).to be == data
		end
	end
end
