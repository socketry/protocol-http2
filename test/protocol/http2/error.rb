# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require 'protocol/http2/error'

describe Protocol::HTTP2::HeaderError do
	let(:error) {subject.new("Invalid header key")}
	
	it "should have a message" do
		expect(error.message).to be == "Invalid header key"
	end
	
	it "should be a kind of StreamClosed" do
		expect(error).to be_a Protocol::HTTP2::StreamClosed
	end
end
