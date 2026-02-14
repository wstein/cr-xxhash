require "spec"
require "../src/vendor/bindings"
require "./support/primitives"

# Load CLI modules explicitly for specs
require "../src/cli/options"
require "../src/cli/hasher"
require "../src/cli/formatter"

# Library module
module XXH
  VERSION = "0.1.0"

  def self.version : UInt32
    LibXXH.versionNumber
  end

  def self.version_string : String
    v = version
    "#{v / 100 / 100}.#{v / 100 % 100}.#{v % 100}"
  end
end
