require 'net/http'

module ParkMedia

  class HTTPHandler
    attr_accessor :logger, :log_request_body, :log_response_body, :log_pretty_print_body

    attr_reader :http

    attr_accessor :cookie

    # @param [Hash] args
    # @option args [Logger] :logger
    # @option args [String] :log_to
    # @option args [Integer] :log_level
    # @option args [String] :server_address
    # @option args [Integer] :server_port
    def initialize(args = {})
      @logger = args[:logger] ? args[:logger].dup : Logger.new(args[:log_to] || STDOUT)
      logger.level = args[:log_level] if args[:log_level]

      hostname = args[:server_address]
      port = args[:server_port]

      @http = Net::HTTP.new(hostname, port)
      http.use_ssl = true

      @log_request_body = args[:log_request_body]
      @log_response_body = args[:log_response_body]
      @log_pretty_print_body = args[:log_pretty_print_body]
    end # initialize

    def http=(new_http)
      @to_s = nil
      @http = new_http
    end # http=

    # Formats a HTTPRequest or HTTPResponse body for log output.
    # @param [HTTPRequest|HTTPResponse] obj
    # @return [String]
    def format_body_for_log_output(obj)
      #obj.body.inspect
      output = ''
      if obj.content_type == 'application/json'
        if @log_pretty_print_body
          output << "\n"
          output << JSON.pretty_generate(JSON.parse(obj.body))
          return output
        else
          return obj.body
        end
      else
        return obj.body.inspect
      end
    end # pretty_print_body

    # Performs final processing of a request then executes the request and returns the response.
    #
    # Debug output for all requests and responses is also handled by this method.
    # @param [HTTPRequest] request
    def process_request(request)

      # USER AGENT MUST HAVE A String/String format or the following error will occur
      # java.lang.IllegalArgumentException: The validated string is empty
      # at org.apache.commons.lang.Validate.notEmpty(Validate.java:321)
      # at org.apache.commons.lang.Validate.notEmpty(Validate.java:339)
      # at com.adobe.ea.model.core.client.Application.<init>(Application.java:36)
      # at com.adobe.ea.model.core.client.Application.fromUserAgent(Application.java:60)
      # at com.adobe.ea.servlets.internal.core.client.ClientInfoService.clientInfoFromRequest(ClientInfoService.java:36)
      # at com.adobe.ea.git.servlets.productions.ProductionsPostServlet.domainLogicCreateProduction(ProductionsPostServlet.java:279)
      request['User-Agent'] = "Ruby/#{RUBY_VERSION}"
      request['Accept'] = 'application/xml'
      request['Cookie'] = cookie if cookie
      logger.debug { redact_passwords(%(REQUEST: #{request.method} #{to_s}#{request.path} HEADERS: #{request.to_hash.inspect} #{log_request_body and request.request_body_permitted? ? "BODY: #{format_body_for_log_output(request)}" : ''})) }

      #TODO LOOKUP REQUEST E-TAG

      response = http.request(request)
      logger.debug { %(RESPONSE: #{response.inspect} HEADERS: #{response.to_hash.inspect} #{log_response_body and response.respond_to?(:body) ? "BODY: #{format_body_for_log_output(response)}" : ''}) }


      #TODO PROCESS ETAG RELATED RESPONSES (304 ?and 412?)

      #TODO RECORD RESPONSE E-TAG

      response
    end # process_request

    # Creates a HTTP DELETE request and passes it to {#process_request} for final processing and execution.
    # @param [String] path
    # @param [Hash] headers
    def delete(path, headers)
      http_to_s = to_s
      path = path.sub(http_to_s) if path.start_with?(http_to_s)
      path = "/#{path}" unless path.start_with?('/')
      request = Net::HTTP::Delete.new(path, headers)
      process_request(request)
    end # delete

    # Creates a HTTP GET request and passes it to {#process_request} for final processing and execution.
    # @param [String] path
    # @param [Hash] headers
    def get(path, headers)
      http_to_s = to_s
      path = path.sub(http_to_s, '') if path.start_with?(http_to_s)
      path = "/#{path}" unless path.start_with?('/')
      request = Net::HTTP::Get.new(path, headers)
      process_request(request)
    end # get

    # Processes put and post request bodies based on the request content type and the format of the data
    # @param [HTTPRequest] request
    # @param [Hash|String] data
    def process_put_and_post_requests(request, data)
      content_type = request['Content-Type'] ||= 'application/x-www-form-urlencoded'
      case content_type
        when 'application/x-www-form-urlencoded'; request.form_data = data
        when 'application/json'; request.body = (data.is_a?(Hash) or data.is_a?(Array)) ? JSON.generate(data) : data
        else
          #data = data.to_s unless request.body.is_a?(String)
          request.body = data
      end
      process_request(request)
    end # process_form_request

    # Creates a HTTP POST request and passes it on for execution
    # @param [Hash] headers
    def post(path, data, headers)
      path = "/#{path}" unless path.start_with?('/')
      request = Net::HTTP::Post.new(path, headers)
      process_put_and_post_requests(request, data)
    end # post

    # Creates a HTTP PUT request and passes it on for execution
    # @param [String] path
    # @param [String|Hash] data
    # @param [Hash] headers
    def put(path, data, headers)
      path = "/#{path}" unless path.start_with?('/')
      request = Net::HTTP::Put.new(path, headers)
      process_put_and_post_requests(request, data)
    end # post

    #def post_form_multipart(path, data, headers)
    #  #headers['Cookie'] = cookie if cookie
    #  #path = "/#{path}" unless path.start_with?('/')
    #  #request = Net::HTTP::Post.new(path, headers)
    #  #request.body = data
    #  #process_request(request)
    #end # post_form_multipart

    # Looks for passwords in a string and redacts them.
    #
    # @param [String] string
    # @return [String]
    def redact_passwords(string)
      string.sub!(/password((=.*)(&|$)|("\s*:\s*".*")(,|\s*|$))/) do |s|
        if s.start_with?('password=')
          _, remaining_string = s.split('&', 2)
          password_mask       = "password=*REDACTED*#{remaining_string ? "&#{redact_passwords(remaining_string)}" : ''}"
        else
          _, remaining_string = s.split('",', 2)
          password_mask       = %(password":"*REDACTED*#{remaining_string ? %(",#{redact_passwords(remaining_string)}) : '"'})
        end
        password_mask
      end
      string
    end # redact_passwords

    # Returns the connection information in a URI format.
    # @return [String]
    def to_s
      @to_s ||= "http#{http.use_ssl? ? 's' : ''}://#{http.address}:#{http.port}"
    end # to_s

  end # HTTPHandler

end

