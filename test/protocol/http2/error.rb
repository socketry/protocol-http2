# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2024, by Samuel Williams.

require "protocol/http2/error"

describe Protocol::HTTP2::StreamError do
	with ".for" do
		it "builds a stream error for a known error code" do
			error = subject.for(Protocol::HTTP2::Error::CANCEL)
			
			expect(error).to be_a(subject)
			expect(error.message).to be == "Stream cancelled."
			expect(error.code).to be == Protocol::HTTP2::Error::CANCEL
		end
		
		it "builds a stream error for an unknown error code" do
			error = subject.for(99)
			
			expect(error).to be_a(subject)
			expect(error.message).to be == "Unknown code: 99!"
			expect(error.code).to be == 99
		end
	end
end

describe Protocol::HTTP2::HeaderError do
	let(:error) {subject.new("Invalid header key")}
	
	it "should have a message" do
		expect(error.message).to be == "Invalid header key"
	end
	
	it "should be a kind of StreamClosed" do
		expect(error).to be_a Protocol::HTTP2::StreamClosed
	end
end
