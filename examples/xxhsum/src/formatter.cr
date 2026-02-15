module XXHSum
  module CLI
    module Formatter
      def self.format_gnu(hex : String, filename : String?, algorithm : CLI::Algorithm) : String
        # Add algorithm prefix for XXH3_64 to match vendor behavior
        hex_with_prefix = case algorithm
                          when CLI::Algorithm::XXH3_64
                            "XXH3_#{hex}"
                          else
                            hex
                          end

        if filename == nil || filename == "-"
          hex_with_prefix
        else
          "#{hex_with_prefix}  #{filename}"
        end
      end

      def self.format_bsd(algo_name : String, hex : String, filename : String) : String
        "#{algo_name} (#{filename}) = #{hex}"
      end

      def self.algo_name(algorithm : CLI::Algorithm) : String
        case algorithm
        when CLI::Algorithm::XXH32   then "xxh32"
        when CLI::Algorithm::XXH64   then "xxh64"
        when CLI::Algorithm::XXH128  then "xxh128"
        when CLI::Algorithm::XXH3_64 then "xxh3"
        else
          raise "Unknown algorithm"
        end
      end
    end
  end
end
