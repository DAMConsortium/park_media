require 'xmlsimple'
module ParkMedia

  class API

    class ResponseParser

      def self.parse(response)
        return response unless response
        return case response.content_type
          when 'application/json'; JSON.parse(response.body)
          when 'text/xml'
            if response.body.start_with?('<')
              _out = XmlSimple.xml_in(response.body, :forcearray => false, :suppressempty => nil) rescue { }
            else
              _out = { }
            end
            _out
          when 'text/html'; HTMLResponseParser.parse(response.body).to_hash
          else; response.respond_to?(:to_hash) ? response.to_hash : response.to_s
        end

      end

    end

    class HTMLResponseParser

      def self.parse(text)
        new(text)
      end # parse

      def initialize(text)
        @raw_text = text
        @attributes = { }

        text[/<b>message<\/b> <u>(.*)<\/u><\/p><p>/]
        @attributes[:message] = $1 if $1

        text[/<b>description<\/b> <u>(.*)<\/u>/]
        @attributes[:description] = $1 if $1

        # m = text.match(/\s*<title>(.*)<\/title>/)
        # @attributes[:title] = m[1] if m
        #
        # m = text.match(/\s*<div id="Status">(.*)<\/div>/)
        # @attributes[:status] = m[1] if m
        #
        # m = text.match(/\s*<div id="Message">(.*)<\/div>/)
        # @attributes[:message] = m[1] if m
        #
        # m = text.match(/\s*<div id="Path">(.*)<\/div>/)
        # @attributes[:path] = m[1] if m
      end # initialize

      def [](key)
        key = key.downcase.to_sym rescue key
        @attributes[key]
      end # []

      # @return [String]
      def to_s
        return "Message: '#{@attributes[:message]}' Description: '#{@attributes[:description]}'" unless @attributes.empty?
        @raw_text
      end # to_s
      alias :inspect :to_s

      # @return [Hash]
      def to_hash
        @attributes
      end # to_hash

    end # HTMLResponseParser

  end

end

# EXAMPLE OF AN HTML RESPONSE
#
# <!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN">
# <html>
# 	<head>
# 		<title>
# 			Apache Tomcat/5.5.9 - Error report
# 		</title>
# 		<style type="text/css">
# <!--H1 {font-family:Tahoma,Arial,sans-serif;color:white;background-color:#525D76;font-size:22px;} H2
# 		{font-family:Tahoma,Arial,sans-serif;color:white;background-color:#525D76;font-size:16px;} H3 {font-family:Tahoma,Arial,sans-serif;color:white;background-color:#525D76;font-size:14px;} BODY
# 		{font-family:Tahoma,Arial,sans-serif;color:black;background-color:white;} B {font-family:Tahoma,Arial,sans-serif;color:white;background-color:#525D76;} P {font-family:Tahoma,Arial,sans-serif;background:white;color:black;font-size:12px;}A {color :
# 		black;}A.name {color : black;}HR {color : #525D76;}-->
# 		</style>
# 	</head>
# 	<body>
# 		<h1>
# 			HTTP Status 500 - Error=ServerError:java.lang.NullPointerException
# 		</h1>
# 		<hr size="\&quot;1\&quot;" noshade="\&quot;noshade\&quot;">
# 		<p>
# 			<b>type</b> Status report
# 		</p>
# 		<p>
# 			<b>message</b> <u>Error=ServerError:java.lang.NullPointerException</u>
# 		</p>
# 		<p>
# 			<b>description</b> <u>The server encountered an internal error (Error=ServerError:java.lang.NullPointerException) that prevented it from fulfilling this request.</u>
# 		</p>
# 		<hr size="\&quot;1\&quot;" noshade="\&quot;noshade\&quot;">
# 		<h3>
# 			Apache Tomcat/5.5.9
# 		</h3>
# 	</body>
# </html>
