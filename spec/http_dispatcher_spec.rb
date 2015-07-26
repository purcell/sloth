require_relative "../lib/http_dispatcher"
require 'stringio'

RSpec.describe HTTPDispatcher do

  let(:handler) { double("handler") }
  let(:path) { "path" + rand(1..1000).to_s }
  let(:method) { "GET" }
  let(:request) { "#{method} /#{path} HTTP/1.0\n\n" }
  let(:response_stream) { StringIO.new }
  let(:request_stream) { StringIO.new(request) }
  let(:handler_response) { StringIO.new("response" + rand.to_s) }
  subject(:dispatcher) { HTTPDispatcher.new(handler) }

  context "with a valid request" do
    it "calls the handler and writes its stream contents to the response" do
      expect(handler).to receive(:handle).with(:get, path).and_return([200, handler_response])
      dispatcher.run(request_stream, response_stream)
      expect(response_stream.string).to eq("HTTP/1.0 200 OK\nContent-Type: text/plain\n\n#{handler_response.string}")
    end
  end

  context "with a different request method" do
    let(:method) { "POST" }
    it "calls the handler and writes its stream contents to the response" do
      expect(handler).to receive(:handle).with(:post, path).and_return([200, handler_response])
      dispatcher.run(request_stream, response_stream)
      expect(response_stream.string).to eq("HTTP/1.0 200 OK\nContent-Type: text/plain\n\n#{handler_response.string}")
    end
  end

  context "with no response body from the handler" do
    it "just responds with the status code" do
      expect(handler).to receive(:handle).with(:get, path).and_return([200, nil])
      dispatcher.run(request_stream, response_stream)
      expect(response_stream.string).to eq("HTTP/1.0 200 OK\n\n")
    end
  end

  context "with a non-200 response code from the handler" do
    it "responds with that status code" do
      expect(handler).to receive(:handle).with(:get, path).and_return([404, nil])
      dispatcher.run(request_stream, response_stream)
      expect(response_stream.string).to eq("HTTP/1.0 404 Not Found\n\n")
    end
  end

  context "with a string response body from the handler" do
    it "responds with that body" do
      expect(handler).to receive(:handle).with(:get, path).and_return([200, "Some response"])
      dispatcher.run(request_stream, response_stream)
      expect(response_stream.string).to eq("HTTP/1.0 200 OK\nContent-Type: text/plain\n\nSome response")
    end
  end

  context "when the handler explodes" do
    it "returns a 500 status code" do
      expect(handler).to receive(:handle).with(:get, path).and_raise(StandardError)
      dispatcher.run(request_stream, response_stream)
      expect(response_stream.string).to eq("HTTP/1.0 500 Internal Server Error\nContent-Type: text/plain\n\nInternal Server Error")
    end
  end
end
