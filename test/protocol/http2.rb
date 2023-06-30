# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require 'protocol/http2/version'

describe Protocol::HTTP2 do
	it "has a version number" do
		expect(Protocol::HTTP2::VERSION).to be =~ /\d+\.\d+\.\d+/
	end
end
