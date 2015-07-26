class HTTPDispatcher

  STATUS_CODES = { 200 => "OK", 404 => "Not Found", 405 => "Method Not Allowed", 500 => "Internal Server Error" }

  def initialize(handler)
    @handler = handler
  end

  def run(request_stream, response_stream)
    request_stream.read =~ /\A([A-Z]+) \/([^ ]+) HTTP\/1\.0\n/
    path = $2
    method = $1
    status, data = begin
                     @handler.handle(method.downcase.to_sym, path)
                   rescue StandardError
                     [500, STATUS_CODES[500]]
                   end

    status_description = STATUS_CODES[status]
    response_stream.write("HTTP/1.0 #{status} #{status_description}\n")
    if data
      response_stream.write("Content-Type: text/plain\n\n")
      response_stream.write(data.respond_to?(:read) ? data.read : data.to_s)
    else
      response_stream.write("\n")
    end
  end
end
