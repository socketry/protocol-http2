# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'connection_context'

describe Protocol::HTTP2::Window do
	let(:window) {subject.new}
	
	with '#consume' do
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
	
	with '#capacity=' do
		it "fails if assignment to capacity causes the window to exceed the maximum flow control window size" do
			expect do
				window.capacity = Protocol::HTTP2::MAXIMUM_ALLOWED_WINDOW_SIZE + 1
			end.to raise_exception(Protocol::HTTP2::FlowControlError)
		end
	end
	
	with '#inspect' do
		it "can generate a string representation" do
			expect(window.inspect).to be =~ /used=0 available=65535 capacity=65535/
		end
	end
end

describe Protocol::HTTP2::LocalWindow do
	let(:window) {subject.new}
	
	with '#consume' do
		it "can consume available capacity" do
			window.consume(100)
			expect(window.wanted).to be == 100
		end
	end
	
	with 'desired window size' do
		let(:window) {subject.new(desired: 200)}
		
		it "can consume available capacity" do
			window.consume(window.available)
			expect(window.wanted).to be == 200
		end
	end
end
