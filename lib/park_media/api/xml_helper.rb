module ParkMedia

  class API

    class XMLGenerator

      class << self

        def root

        end

        def process_data(data, options)
          generate_xml_child(data, options)
        end

        def generate_xml_child(data, options = { })
          data.map { |k, v| "<#{k}>#{v.is_a?(Hash) ? generate_xml_child(v, options) : v}</#{k}>" }.join(options[:separator])
        end

        def generate_xml_metadata(data, options = { })
          data.map { |k, v| %(<metadata name="#{k}">#{v}</metadata>) }.join(options[:separator])
        end

        def generate_xml(data, options = { })
          separator = options[:separator]

          content = process_data(data, options)

          [ %(<?xml version="1.0" encoding="utf-8"?>\n<kdata xmlns:kdata="http://www.kuvata.com/kdata">), content, '</kdata>' ].join(separator)
        end

      end

    end

    class AssetEditXMLGenerator < XMLGenerator

      class << self

        def process_data(data, options = { })
          separator = options[:separator]

          data.map { |key, value|
            if %w(asset-metadata metadata).include? key.to_s
              xml = ['<asset-metadata>', generate_xml_metadata(value, options), '</asset-metadata>'].join(separator)
            else
              xml = "<#{key}>#{value.is_a?(Hash) ? generate_xml_child(value, options) : value}</#{key}>"
            end
            xml
          }.join(separator)
        end

      end

    end

  end

end