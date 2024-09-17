# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require "protocol/http2/priority_frame"
require "protocol/http2/a_frame"

describe Protocol::HTTP2::Priority do
	let(:priority) {subject.new}
	
	with ".default" do
		let(:priority) {subject.default}
		
		it "has a default weight" do
			expect(priority.weight).to be == 16
		end
	end
	
	with "#weight" do
		it "can be set" do
			priority.weight = 42
			expect(priority.weight).to be == 42
			
			priority.weight = 1
			expect(priority.weight).to be == 1
			
			priority.weight = 256
			expect(priority.weight).to be == 256
		end
		
		it "must be in range" do
			expect do
				priority.weight = 0
			end.to raise_exception(ArgumentError)
			
			expect do
				priority.weight = 257
			end.to raise_exception(ArgumentError)
		end
	end
end

describe Protocol::HTTP2::PriorityFrame do
	let(:priority) {Protocol::HTTP2::Priority.new(true, 42, 7)}
	let(:frame) {subject.new}
	
	it_behaves_like Protocol::HTTP2::AFrame do
		def before
			frame.pack priority
			
			super
		end
	end
	
	with "#pack" do
		it "packs priority" do
			frame.pack priority
			
			expect(frame.length).to be == 5
		end
	end
	
	with "#unpack" do
		it "unpacks priority" do
			frame.pack priority
			
			expect(frame.unpack).to be == priority
		end
	end
	
	with "#read_payload" do
		let(:stream) {StringIO.new("!!!")}
		
		it "must be 4 bytes long" do 
			frame.pack(priority)
			expect(frame.length).to be == 5
			
			frame.length = 3
			
			expect do
				frame.read_payload(stream)
			end.to raise_exception(Protocol::HTTP2::FrameSizeError)
		end
	end
end
