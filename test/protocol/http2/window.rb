# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require "protocol/http2/connection_context"
require "json"

describe Protocol::HTTP2::Window do
	let(:window) {subject.new}
	
	with "#consume" do
		it "can consume available capacity" do
			expect(window).not.to be(:full?)
			expect(window).to be(:available?)
			
			expect(window.consume(100)).to be == 100
			expect(window).not.to be(:full?)
			
			window.consume(window.available)
			expect(window).to be(:full?)
			expect(window).not.to be(:available?)
		end
	end
	
	with "#capacity=" do
		it "fails if assignment to capacity causes the window to exceed the maximum flow control window size" do
			expect do
				window.capacity = Protocol::HTTP2::MAXIMUM_ALLOWED_WINDOW_SIZE + 1
			end.to raise_exception(Protocol::HTTP2::FlowControlError)
		end
	end
	
	with "#inspect" do
		it "can generate a string representation" do
			expect(window.inspect).to be =~ /available=65535 used=0 capacity=65535/
		end
	end
end

describe Protocol::HTTP2::LocalWindow do
	let(:window) {subject.new}
	
	with "#consume" do
		it "can consume available capacity" do
			window.consume(100)
			expect(window.wanted).to be == 100
		end
	end
	
	with "desired window size" do
		let(:window) {subject.new(desired: 200)}
		
		it "can consume available capacity" do
			window.consume(window.available)
			expect(window.wanted).to be == 200
		end
		
		it "is not limited if the half the desired capacity is available" do
			expect(window).not.to be(:limited?)
			
			# Consume the entire window:
			window.consume(window.available)
			
			expect(window).to be(:limited?)
			
			# Expand the window by at least half the desired capacity:
			window.expand(window.desired / 2)
			
			expect(window).not.to be(:limited?)
		end
	end
	
	with "#limited?" do
		it "becomes limited after half the capacity is consumed" do
			expect(window).not.to be(:limited?)
			
			# Consume a little more than half:
			window.consume(window.capacity / 2 + 2)
			
			expect(window).to be(:limited?)
		end
	end
end
