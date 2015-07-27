class HTTPDispatcher

  STATUS_CODES = {
    200 => "OK",
    400 => "Bad Request",
    404 => "Not Found",
    405 => "Method Not Allowed",
    500 => "Internal Server Error"
  }

  def initialize(handler, log=STDERR)
    @handler = handler
    @log = log
  end

  def run(request_stream, response_stream)
    status, data, headers = if request = read_request(request_stream)
                              method, path = request
                              begin
                                @handler.handle(method.downcase.to_sym, path)
                              rescue StandardError => e
                                log_error(e)
                                [500, STATUS_CODES[500], { "Content-Type" => "text/plain" }]
                              end
                            else
                              [400, nil]
                            end

    status_description = STATUS_CODES[status]
    response_stream.write("HTTP/1.0 #{status} #{status_description}#{LINE_SEP}")
    (headers || {}).each do |key, value|
      response_stream.write("#{key}: #{value}#{LINE_SEP}")
    end
    response_stream.write(LINE_SEP)
    if data
      response_stream.write(data.respond_to?(:read) ? data.read : data.to_s)
    end
  end

  private

  LINE_SEP = "\r\n"

  def log_error(e)
    @log.puts("Error: #{e}")
  end

  def read_request(request_stream)
    begin
      request_line = request_stream.readline(LINE_SEP)
      if request_line =~ /\A([A-Z]+) \/([^ ]*) HTTP\/1\.[01]#{LINE_SEP}/
        path = $2
        method = $1
        while (nextline = request_stream.readline(LINE_SEP)) != LINE_SEP
          # skip header
        end
        [method, path]
      end
    rescue IOError => e
      log_error(e)
    end
  end
end
