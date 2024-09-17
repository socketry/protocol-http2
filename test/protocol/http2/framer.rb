# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2024, by Samuel Williams.

require "protocol/http2/framer"

describe Protocol::HTTP2::Framer do
	let(:stream) {StringIO.new}
	let(:framer) {subject.new(stream)}
	
	with "#flush" do
		it "flushes the underlying stream" do
			expect(stream).to receive(:flush)
			framer.flush
		end
	end
	
	with "#closed?" do
		it "reports the status of the underlying stream" do
			expect(stream).to receive(:closed?).and_return(true)
			expect(framer).to be(:closed?)
		end
	end
	
	with "#read_connection_preface" do
		with "invalid preface" do
			let(:stream) {StringIO.new("Hello World!")}
			
			it "fails with a handshake error" do
				expect{framer.read_connection_preface}.to raise_exception(Protocol::HTTP2::HandshakeError)
			end
		end
		
		with "valid preface" do
			let(:stream) {StringIO.new(Protocol::HTTP2::CONNECTION_PREFACE)}
			
			it "reads the connection preface" do
				expect(framer.read_connection_preface).to be == Protocol::HTTP2::CONNECTION_PREFACE
			end
		end
	end
	
	with "#read_frame" do
		with "invalid frame" do
			let(:stream) {StringIO.new("!")}
			
			it "fails with a end-of-file error" do
				expect{framer.read_frame}.to raise_exception(EOFError)
			end
		end
	end
end
