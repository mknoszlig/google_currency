require 'money'
require 'open-uri'
require 'multi_json'

class Money
  module Bank

    class GoogleCurrencyFetchError < Error
    end

    class GoogleCurrency < Money::Bank::VariableExchange

      SERVICE_HOST = "www.google.com"
      SERVICE_PATH = "/finance/converter"

      # @return [Hash] Stores the currently known rates.
      attr_reader :rates

      ##
      # Clears all rates stored in @rates
      #
      # @return [Hash] The empty @rates Hash.
      #
      # @example
      #   @bank = GoogleCurrency.new  #=> <Money::Bank::GoogleCurrency...>
      #   @bank.get_rate(:USD, :EUR)  #=> 0.776337241
      #   @bank.flush_rates           #=> {}
      def flush_rates
        @mutex.synchronize{
          @rates = {}
        }
      end

      ##
      # Clears the specified rate stored in @rates.
      #
      # @param [String, Symbol, Currency] from Currency to convert from (used
      #   for key into @rates).
      # @param [String, Symbol, Currency] to Currency to convert to (used for
      #   key into @rates).
      #
      # @return [Float] The flushed rate.
      #
      # @example
      #   @bank = GoogleCurrency.new    #=> <Money::Bank::GoogleCurrency...>
      #   @bank.get_rate(:USD, :EUR)    #=> 0.776337241
      #   @bank.flush_rate(:USD, :EUR)  #=> 0.776337241
      def flush_rate(from, to)
        key = rate_key_for(from, to)
        @mutex.synchronize{
          @rates.delete(key)
        }
      end

      ##
      # Returns the requested rate.
      #
      # @param [String, Symbol, Currency] from Currency to convert from
      # @param [String, Symbol, Currency] to Currency to convert to
      #
      # @return [Float] The requested rate.
      #
      # @example
      #   @bank = GoogleCurrency.new  #=> <Money::Bank::GoogleCurrency...>
      #   @bank.get_rate(:USD, :EUR)  #=> 0.776337241
      def get_rate(from, to)
        @mutex.synchronize{
          @rates[rate_key_for(from, to)] ||= fetch_rate(from, to)
        }
      end

      private

      ##
      # Queries for the requested rate and returns it.
      #
      # @param [String, Symbol, Currency] from Currency to convert from
      # @param [String, Symbol, Currency] to Currency to convert to
      #
      # @return [BigDecimal] The requested rate.
      def fetch_rate(from, to)
        from, to = Currency.wrap(from), Currency.wrap(to)

        data = build_uri(from, to).read
        extract_rate(data)
      end

      ##
      # Build a URI for the given arguments.
      #
      # @param [Currency] from The currency to convert from.
      # @param [Currency] to The currency to convert to.
      #
      # @return [URI::HTTP]
      def build_uri(from, to)
        uri = URI::HTTP.build(
          :host  => SERVICE_HOST,
          :path  => SERVICE_PATH,
          :query => "a=1&from=#{from.iso_code}&to=#{to.iso_code}"
        )
      end

      ##
      # Takes the invalid JSON returned by Google and fixes it.
      #
      # @param [String] data The JSON string to fix.
      #
      # @return [Hash]
      def fix_response_json_data(data)
        data.gsub!(/lhs:/, '"lhs":')
        data.gsub!(/rhs:/, '"rhs":')
        data.gsub!(/error:/, '"error":')
        data.gsub!(/icc:/, '"icc":')
        data.gsub!(Regexp.new("(\\\\x..|\\\\240)"), '')

        MultiJson.decode(data)
      end

      ##
      # Takes the 'rhs' response from Google and decodes it.
      #
      # @param [String] data The google rate string to decode.
      #
      # @return [BigDecimal]
      def extract_rate(data)
        case data
          when /<span class=bld>(\d+\.?\d*) [A-Z]{3}<\/span>/
          BigDecimal($1)
          when /Could not convert\./
          raise UnknownRate
        else
          raise GoogleCurrencyFetchError
        end
      end
    end
  end
end
