module XXH
  # Base exception class for all XXH errors
  class Error < Exception
  end

  # State management errors (invalid state, memory corruption)
  class StateError < Error
  end

  # Secret-related errors (invalid secret size, generation failure)
  class SecretError < Error
  end

  # Error code conversion and validation
  module ErrorHandler
    # Check C function error code and raise if error
    # Raises: XXH::Error if error_code indicates failure
    def self.check!(error_code : LibXXH::XXHErrorcode, message : String) : Nil
      case error_code
      when LibXXH::XXHErrorcode::XXH_OK
        # Success - no exception
      when LibXXH::XXHErrorcode::XXH_ERROR
        raise Error.new(message)
      else
        raise Error.new("Unknown error code: #{error_code} - #{message}")
      end
    end

    # Convert C error code to human-readable string
    def self.error_message(error_code : LibXXH::XXHErrorcode) : String
      case error_code
      when LibXXH::XXHErrorcode::XXH_OK
        "Success (XXH_OK)"
      when LibXXH::XXHErrorcode::XXH_ERROR
        "General error (XXH_ERROR)"
      else
        "Unknown error code: #{error_code}"
      end
    end
  end
end
