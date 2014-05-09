require 'json'
require 'optparse'
require 'pp'

require 'park_media/api'

module ParkMedia

  class API

    ENV_VAR_NAME_PARK_MEDIA_COOKIE = 'PARK_MEDIA_API_SESSION_COOKIE'

    def self.default_options; { } end



    class CLI

      attr_accessor :logger, :api

      LOGGING_LEVELS = {
        :debug => Logger::DEBUG, :info => Logger::INFO, :warn => Logger::WARN, :error => Logger::ERROR,
        :fatal => Logger::FATAL
      }

      def options_file_path
        file_path = File.join(File.expand_path('.'), "#{File.basename($0, '.rb')}_options")
        return file_path if File.exists?(file_path)
        return File.expand_path(File.basename($0, '.*'), '~/.options')
      end

      def parse_options
        options = ParkMedia::API.default_options.merge({
          :server_address => API::DEFAULT_SERVER_ADDRESS,
          :server_port => API::DEFAULT_SERVER_PORT,
          :log_to => STDERR,
          :log_level => Logger::WARN,
          :options_file_path => options_file_path,
        })
        op = OptionParser.new
        op.on('--park-media-server-address ADDRESS', 'The Park Media server address.',
              "\tdefault: #{options[:server_address]}") { |v| options[:server_address] = v }
        op.on('--park-media-server-port PORT', 'The port on the Park Media server to connect to.',
              "\tdefault: #{options[:server_port]}") { |v| options[:server_port] = v }
        op.on('--park-media-username USERNAME', 'The username to login with. This will be ignored if cookie contents is set and the force login parameter is false.',
              "\tdefault: #{options[:username]}") { |v| options[:username] = v }
        op.on('--park-media-password PASSWORD', 'The password to login with. This will be ignored if cookie contents is set and the force login parameter is false.',
              "\tdefault: #{options[:password]}") { |v| options[:password] = v }
        op.on('--force-login', 'Forces a new cookie even if cookie information is present.') { |v| options[:force_login] = v }
        op.on('--method-name METHODNAME', '') { |v| options[:method_name] = v }
        op.on('--method-arguments JSON', '') { |v| options[:method_arguments] = v }
        op.on('--pretty-print', '') { |v| options[:pretty_print] = v }
        op.on('--cookie-contents CONTENTS', 'Sets the cookie contents.') { |v| options[:cookie_contents] = v }
        op.on('--cookie-file-name FILENAME',
              'Sets the cookie contents from the contents of a file.') { |v| options[:cookie_file_name] = v }
        op.on('--set-cookie-env',
              "Saves cookie contents to an environmental variable named #{ParkMedia::API::ENV_VAR_NAME_PARK_MEDIA_COOKIE}") do |v|
          options[:set_cookie_env_var] = v
        end
        op.on('--set-cookie-file FILENAME', 'Saves cookie contents to a file.') { |v| options[:set_cookie_file_name] = v }
        op.on('--log-to FILENAME', 'Log file location.', "\tdefault: STDERR") { |v| options[:log_to] = v }
        op.on('--log-level LEVEL', LOGGING_LEVELS.keys, "Logging level. Available Options: #{LOGGING_LEVELS.keys.join(', ')}",
              "\tdefault: #{LOGGING_LEVELS.invert[options[:log_level]]}") { |v| options[:log_level] = LOGGING_LEVELS[v] }
        op.on('--[no-]options-file [FILENAME]', 'Path to a file which contains default command line arguments.', "\tdefault: #{options[:options_file_path]}" ) { |v| options[:options_file_path] = v}
        op.on_tail('-h', '--help', 'Show this message.') { puts op; exit }
        op.parse!(ARGV.dup)

        options_file_path = options[:options_file_path]
        # Make sure that options from the command line override those from the options file
        op.parse!(ARGV.dup) if op.load(options_file_path)
        options
      end # parse_options

      def initialize(args = {})
        args = parse_options.merge(args)
        initialize_logger(args)

        @api = ParkMedia::API.new(args)

        ## LIST METHODS
        #methods = api.methods; methods -= Object.methods; methods.sort.each { |method| puts "#{method} #{api.method(method).parameters}" }; exit

        args[:cookie_contents] = File.read(args[:cookie_file_name]) if args[:cookie_file_name]
        args[:cookie_contents] ||= ENV[ENV_VAR_NAME_PARK_MEDIA_COOKIE]

        api.http_cookie = cookie_contents = args[:cookie_contents] if args[:cookie_contents]
        api.http.log_request_body = true
        api.http.log_response_body = true
        api.http.log_pretty_print_body = true

        begin
          cookie_contents = api.login(args) unless cookie_contents && !args[:force_login]
          abort "Error performing login on #{api.http.to_s}. #{api.parsed_response.inspect}" unless cookie_contents
        rescue => e
          abort "Error performing login on #{api.http.to_s}. #{e.message}"
        end

        if cookie_contents
          #logger.debug { "Cookie Contents Set: #{cookie_contents}" }
          ENV[ENV_VAR_NAME_PARK_MEDIA_COOKIE] = cookie_contents if args[:set_cookie_env_var]
          File.write(args[:set_cookie_file_name], cookie_contents) if args[:set_cookie_file_name]
        end #

        method_name = args[:method_name]
        send(method_name, args[:method_arguments], :pretty_print => args[:pretty_print]) if method_name

      end # initialize

      def initialize_logger(args = { })
        @logger = args[:logger] ||= Logger.new(args[:log_to] || STDERR)

        log_level = args[:log_level]
        @logger.level = log_level if log_level
        @logger
      end

      class ResponseHandler

        class << self

          attr_accessor :api, :response

          # def user_create(*args)
          #   m = api.response.body.match(/<title>(.*)<\/title>/)
          #   $1
          # end # user_create

        end # << self

      end # ResponseHandler


      def send(method_name, method_arguments, params = {})
        method_name = method_name.to_sym
        logger.debug { "Executing Method: #{method_name}" }

        send_arguments = [ method_name ]

        if method_arguments
          method_arguments = JSON.parse(method_arguments) if method_arguments.is_a?(String) and method_arguments.start_with?('{', '[')
          send_arguments << method_arguments
        end

        response = api.__send__(*send_arguments)

        if api.response.code.to_i.between?(500,599)
          puts api.parsed_response
          exit
        end

        if ResponseHandler.respond_to?(method_name)
          ResponseHandler.api = api
          ResponseHandler.response = response
          response = ResponseHandler.__send__(*send_arguments)
        end

        if params[:pretty_print]
          if response.is_a?(String) and response.lstrip.start_with?('{', '[')
            puts JSON.pretty_generate(JSON.parse(response))
          else
            pp response
          end
        else
          response = JSON.generate(response) if response.is_a?(Hash) or response.is_a?(Array)
          puts response
        end
        exit
      end # send

    end # CLI

  end

end