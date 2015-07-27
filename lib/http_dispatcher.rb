class HTTPDispatcher

  STATUS_CODES = {
    200 => "OK",
    400 => "Bad Request",
    404 => "Not Found",
    405 => "Method Not Allowed",
    500 => "Internal Server Error"
  }

  def initialize(handler, access_log=STDOUT, error_log=STDERR)
    @handler = handler
    @access_log = access_log
    @error_log = error_log
  end

  def run(request_stream, response_stream)
    path = method = "-"
    request_headers = {}
    status, body, response_headers =
                  if request = read_request(request_stream)
                    method, path, request_headers = request
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

    response_headers ||= {}

    gzip = (response_headers["Content-Type"] &&
            response_headers["Content-Type"].start_with?("text/") &&
            request_headers["Accept-Encoding"] &&
            request_headers["Accept-Encoding"]["gzip"])

    data = body.respond_to?(:read) ? body.read : body.to_s

    if gzip
      response_headers["Content-Encoding"] = "gzip"
      data = Zlib.deflate(data)
      response_headers["Content-Length"] = data.bytesize
    end

    response_headers.each do |key, value|
      response_stream.write("#{key}: #{value}#{LINE_SEP}")
    end
    response_stream.write(LINE_SEP)
    if data
      response_stream.write(data)
    end
    @access_log.puts("#{method} #{path} #{status}")
  end

  private

  LINE_SEP = "\r\n"

  def log_error(e)
    @error_log.puts("Error: #{e}: #{e.backtrace.join("\n")}")
  end

  def read_request(request_stream)
    begin
      request_line = request_stream.readline(LINE_SEP)
      if request_line =~ /\A([A-Z]+) \/([^ ]*) HTTP\/1\.[01]#{LINE_SEP}/
        path = $2
        method = $1
        headers = {}
        while (nextline = request_stream.readline(LINE_SEP)) != LINE_SEP
          if nextline =~ /\A(\S+): (\S.*?)#{LINE_SEP}/
            headers[$1] = $2
          else
            @error_log.puts("malformed header: #{nextline.inspect}")
          end
        end
        [method, path, headers]
      end
    rescue IOError => e
      log_error(e)
    end
  end
end
