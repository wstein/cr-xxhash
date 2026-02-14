require "../common/types"
require "../common/constants"

module XXH
  module XXH3
    module Secret
      def self.default : ::XXH::Secret
        size = LibXXH::XXH3_SECRET_DEFAULT_SIZE
        bytes = Bytes.new(size)
        size.times { |i| bytes[i] = ((i * 131) % 256).to_u8 }
        bytes
      end

      def self.valid?(secret : ::XXH::Secret) : Bool
        secret.size >= LibXXH::XXH3_SECRET_SIZE_MIN
      end
    end
  end
end
