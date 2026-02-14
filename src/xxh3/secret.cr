require "../common/types"

module XXH
  module XXH3
    module Secret
      def self.default : ::XXH::Secret
        Bytes.new(XXH3_SECRET_DEFAULT_SIZE) { |i| (i * 131) % 256 }
      end
    end
  end
end
