require "./common/constants"
require "./common/types"
require "./common/errors"
require "./bindings/lib_xxh"
require "./bindings/safe"
require "./xxh32/hasher"
require "./xxh32/state"
require "./xxh32/canonical"
require "./xxh64/hasher"
require "./xxh64/state"
require "./xxh64/canonical"
require "./xxh3/hasher_64"
require "./xxh3/hasher_128"
require "./xxh3/state"
require "./xxh3/canonical"
require "./xxh3/secret"

# Main namespace entry point for XXH library
module XXH
  VERSION = "0.1.0"

  # Query vendored xxHash C library version
  def self.version_number : UInt32
    Bindings::Version.number
  end

  def self.version : String
    Bindings::Version.to_s
  end
end
