require 'logger'

require 'park_media/http_handler'
require 'park_media/api/response_parser'
require 'park_media/api/xml_helper'

module ParkMedia

  class API

    attr_accessor :logger, :http, :cookie, :base_path, :response, :parse_response, :error
    #attr_accessor :logger, :http, :response, :identity

    DEFAULT_SERVER_ADDRESS = 'eval.parkmedia.tv'
    DEFAULT_SERVER_PORT = 8123
    DEFAULT_BASE_PATH = '/kmm/svc'

    def initialize(args = { })
      initialize_logger(args)

      args[:server_address] ||= DEFAULT_SERVER_ADDRESS
      args[:server_port] ||= DEFAULT_SERVER_PORT

      initialize_http_handler(args)


      @base_path = args.fetch(:base_path, DEFAULT_BASE_PATH)
      @base_path ||= '' # In case we pass in :base_path as nil or false
      @base_path = base_path[0..-2] if base_path.is_a?(String) and base_path.end_with?('/')

      @parse_response = args.fetch(:parse_response, true)
    end

    def initialize_logger(args = { })
      @logger = args[:logger] ||= begin
        log_to = args[:log_to] || STDERR
        logger = Logger.new(log_to)

        log_level = args[:log_level] ||= Logger::INFO
        logger.level = log_level

        logger
      end
    end

    # Sets the connection information.
    # @see HTTPHandler#new
    def initialize_http_handler(args = {})
      @http = HTTPHandler.new(args)
      logger.debug { "Connection Set: #{http.to_s}" }
    end # connect

    # Returns the stored cookie information
    # @return [String]
    def http_cookie
      http.cookie
    end # http_cookie

    # Sets the cookie information that will be used with subsequent calls to the HTTP server.
    # @param [String] content
    def http_cookie=(content)
      logger.debug { content ? "Setting Cookie: #{content}" : 'Clearing Cookie' }
      http.cookie = content
    end # http_cookie=

    def process_path(path)
      "#{base_path}/#{path}"
    end

    # Executes a HTTP DELETE request
    # @param [String] path
    # @param [Hash] headers
    # @return [String|Hash] If parse_response? is true then there will be an attempt to parse the response body based on
    # it's content type. If content type is not supported then the response body is returned.
    #
    # If parse_response? is false then the response body is returned.
    def http_delete(path, headers = {})
      clear_response
      path = process_path(path)
      @success_code = 204
      @response = http.delete(path, headers)
      parse_response? ? parsed_response : response.body
    end # http_delete

    # Executes a HTTP GET request and returns the response
    # @param [String] path
    # @param [Hash] headers
    # @return [String|Hash] If parse_response? is true then there will be an attempt to parse the response body based on
    # it's content type. If content type is not supported then the response body is returned.
    #
    # If parse_response? is false then the response body is returned.
    def http_get(path, headers = { })
      clear_response
      path = process_path(path)
      @success_code = 200
      @response = http.get(path, headers)
      parse_response? ? parsed_response : response.body
    end # http_get

    # Executes a HTTP POST request
    # @param [String] path
    # @param [String] data
    # @param [Hash] headers
    # @return [String|Hash] If parse_response? is true then there will be an attempt to parse the response body based on
    # it's content type. If content type is not supported then the response body is returned.
    #
    # If parse_response? is false then the response body is returned.
    def http_post(path, data, headers = {})
      clear_response
      path = process_path(path)
      @success_code = 201
      @response = http.post(path, data, headers)
      parse_response? ? parsed_response : response.body
    end # http_post

    # Formats data as form url encoded and calls {#http_post}
    # @param [String] path
    # @param [Hash] data
    # @param [Hash] headers
    # @return [String|Hash] If parse_response? is true then there will be an attempt to parse the response body based on
    # it's content type. If content type is not supported then the response body is returned.
    #
    # If parse_response? is false then the response body is returned.
    def http_post_form(path, data, headers = {})
      headers['Content-Type'] = 'application/x-www-form-urlencoded'
      #data_as_string = URI.encode_www_form(data)
      #post(path, data_as_string, headers)
      clear_response
      path = process_path(path)
      @success_code = 201
      @response = http.post(path, data, headers)
      parse_response? ? parsed_response : response.body
    end # http_post_form

    # Formats data as JSON and calls {#http_put}
    # @param [String] path
    # @param [Hash] data
    # @param [Hash] headers
    # @return [String|Hash] If parse_response? is true then there will be an attempt to parse the response body based on
    # it's content type. If content type is not supported then the response body is returned.
    #
    # If parse_response? is false then the response body is returned.
    def http_post_json(path, data, headers = {})
      headers['Content-Type'] ||= 'application/json'
      data_as_string = JSON.generate(data)
      http_post(path, data_as_string, headers)
    end # http_post_json

    #def http_post_form_multipart(path, data, headers = { })
    #  headers['Content-Type'] = 'multipart/form-data'
    #
    #end # http_post_form_multipart


    # Executes a HTTP PUT request
    # @param [String] path
    # @param [String] data
    # @param [Hash] headers
    # @return [String|Hash] If parse_response? is true then there will be an attempt to parse the response body based on
    # it's content type. If content type is not support then the respond body is returned.
    #
    # If parse_response? is false then the response body is returned.
    def http_put(path, data, headers = {})
      clear_response
      path = process_path(path)
      @success_code = 200
      @response = http.put(path, data, headers)
      parse_response? ? parsed_response : response.body
    end # http_put

    def hash_to_xml(hash, options = { })
      default_xml_simple_options = {
        :NoAttr => true,
        :RootName => 'kdata',
        :XMLDeclaration => '<?xml version="1.0" encoding="utf-8"?>'
      }
      xml_simple_options = default_xml_simple_options.merge(options[:xml_simple_options] || { })
      xml = XmlSimple.xml_out(hash, xml_simple_options)
      xml.gsub!('<kdata>', '<kdata xmlns:kdata="http://www.kuvata.com/kdata">')
      xml
    end

    def http_put_xml(path, data, headers = { }, options = { })
      headers['Content-Type'] = 'text/xml'
      data_as_string = hash_to_xml(data, options)
      http_put(path, data_as_string, headers)
    end

    # Formats data as JSON and calls {#http_put}
    def http_put_json(path, data, headers = { })
      headers['Content-Type'] = 'application/json'
      data_as_string = JSON.generate(data)
      http_put(path, data_as_string, headers)
    end # put_json


    # The http response code that indicates success for the request being made.
    def success_code
      @success_code
    end # success_code
    private :success_code

    # Returns true if the response code equals the success code that was set by the method.
    def success?
      return nil unless @success_code
      response.code == @success_code.to_s
    end # success?

    def clear_response
      @error = { }
      @success_code = @response = @parsed_response = nil
    end # clear_response
    private :clear_response

    # Returns true if the response body parsing option has been set to true.
    def parse_response?
      parse_response
    end # parse_response?
    private :parse_response?

    # Parses the response body based on the response's content-type header value
    # @return [nil|String|Hash]
    #
    # Will pass through the response body unless the content type is supported.
    def parsed_response
      #logger.debug { "Parsing Response: #{response.content_type}" }
      @parsed_response ||= ResponseParser.parse(response)
    end # parsed_response

    ##################################################################################################################
    # API METHODS

    # Login.
    #
    # @param [Hash] args
    # @option params [String] :username
    # @option params [String] :password
    # @return [String] The contents of the set-cookie header
    def login(args = { })
      # POST /svc/Login
      # Host: eval.parkmedia.tv
      # Content-type: application/x-www-form-urlencoded
      # Content-length: 25
      #
      # username=foo&password=bar

      # ERROR RESPONSE
      # --------------
      # HTTP/1.0 403 Access Forbidden
      # Content-type: text/plain
      #
      # Error=BadAuthentication

      # SUCCESS RESPONSE
      # ----------------
      # HTTP/1.0 200 OK
      # Content-type: text/plain
      # Set-Cookie: JSESSIONID=123456789
      #
      # JSESSIONID=123456789

      self.http_cookie = nil
      data = { }

      username = args[:username]
      password = args[:password]

      data['password'] = password if password
      data['username'] = username if username

      #logger.debug { "Logging In As User: '#{username}' Using Password: #{password ? 'yes' : 'no'}" }
      http_post_form('Login', data)
      self.http_cookie = response['set-cookie'] if response and response.code == '200'
      http_cookie
    end

    def devices(options = { })
      # GET /svc/Devices
      # Host: eval.parkmedia.tv
      # Cookie: JSESSIONID=123456789

      http_get('Devices')
    end

    def device(id)
      # GET /svc/Device/987
      # Host: eval.parkmedia.tv
      # Cookie: JSESSIONID=123456789
      id = id.values if id.is_a?(Hash)

      http_get("Devices/#{id}")
    end

    def device_screenshot(id)
      # GET /svc/DeviceScreenshot/987
      # Host: eval.parkmedia.tv
      # Cookie: JSESSIONID=123456789
      id = id.values if id.is_a?(Hash)

      http_get("DevicesScreenshot/#{id}")
    end

    def device_command_send(device_id, command)
      # POST /svc/DeviceCommand
      # Host: eval.parkmedia.tv
      # Content-type: application/x-www-form-urlencoded
      # Content-length: 38
      # Cookie: JSESSIONID=123456789
      #
      # deviceId=987&command=uploadScreenshot

      data = { 'deviceId' => device_id, 'command' => command }

      http_post_form('DeviceCommand', data)
    end

    def device_command_retrieve(device_command_id)
      # GET /svc/DeviceCommand/654321
      # Host: eval.parkmedia.tv
      # Cookie: JSESSIONID=123456789
      device_command_id = device_command_id.values if device_command_id.is_a?(Hash)

      http_get("DeviceCommand/#{device_command_id}")
    end

    def device_groups
      # GET /svc/DeviceGroups
      # Host: eval.parkmedia.tv
      # Cookie: JSESSIONID=123456789

      http_get('DeviceGroups')
    end

    def assets(options = { })
      # GET /svc/Assets?options=metadata
      # Host: eval.parkmedia.tv
      # Cookie: JSESSIONID=123456789

      http_get('Assets')
    end

    def asset(id)
      # GET /svc/Asset/11223
      # Host: eval.parkmedia.tv
      # Cookie: JSESSIONID=123456789
      id = id.values.first if id.is_a?(Hash)

      http_get("Asset/#{id}")
    end

    def asset_create(args = { })
      # POST /svc/Asset
      # Host: eval.parkmedia.tv
      # Content-type: application/x-www-form-urlencoded
      # Content-length: 85
      # Cookie: JSESSIONID=123456789
      # assetType=Image&assetName=myasset&assetFileExtension=jpg&assetFileData=A0A1A2A3A4A5

      data = args
      http_post_form('Asset', data)
    end

    def asset_edit(args = { })
      # PUT /svc/Asset/11223 Host: eval.parkmedia.tv
      # Content-type: application/x-www-form-urlencoded Content-length: 208
      # Cookie: JSESSIONID=123456789
      # Etag: ABC123
      # <?xml version="1.0" encoding="utf-8"?>
      # <kdata xmlns:kdata="http://www.kuvata.com/kdata">
      #   <assetName>newassetname</assetName>
      #   <assetFileData extension="jpg">A0A1A2A3A5A5</assetFileData>
      # </kdata >
      asset_id = args.delete(:asset_id) { }
      raise ArgumentError ':asset_id is a required argument.' unless asset_id

      data = args
      xml = AssetEditXMLGenerator.generate_xml(data)
      http_put("Asset/#{asset_id}", xml, 'Content-Type' => 'text/xml')
    end

    def content_scheduler(device_id)
      # POST /svc/ContentScheduler
      # Host: eval.parkmedia.tv
      # Content-type: application/x-www-form-urlencoded
      # Content-length: 28
      # Cookie: JSESSIONID=123456789
      #
      # deviceIds=12345,45678,78965
      device_id = device_id.values if device_id.is_a?(Hash)

      data = { 'deviceIds' => device_id.join(',') }

      http_post_form('ContentSchedule', data)
    end

    def asset_summary_report(args = { })
      # POST /svc/AssetSummaryReport
      # Host: eval.parkmedia.tv
      # Content-type: application/x-www-form-urlencoded
      # Content-length: 64
      # Cookie: JSESSIONID=123456789
      #
      # assetIds=12345,45678&startDate=2010-08-11&endDate=2010-08-11
      asset_id = args[:asset_id]
      asset_id = asset_id.join(',') if asset_id.is_a?(Array)

      start_date = args[:start_date]
      end_date = args[:end_date]

      data = {
        'assetIds' => asset_id
      }
      data['startDate'] = start_date if start_date
      data['endDate'] = end_date if end_date

      http_post_form('AssetSummaryReport', data)
    end

  end

end