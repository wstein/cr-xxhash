require "./spec_helper"

describe "XXHSum SIMD mode" do
  it "detects available SIMD backends by platform" do
    backends = XXHSum::CLI::Options.simd_backends
    backends.should contain("scalar")

    {% if flag?(:x86_64) %}
      backends.should contain("sse2")
      backends.should contain("avx2")
      backends.should contain("avx512")
    {% elsif flag?(:aarch64) %}
      backends.should contain("neon")
    {% end %}
  end

  it "shows available backends in help text" do
    help = XXHSum::CLI::Options.help_text
    help.should contain("--SIMD [BACKEND]")
    help.should contain("(NOT IMPLEMENTED)")
    help.should contain("scalar")

    {% if flag?(:aarch64) %}
      help.should contain("neon")
    {% elsif flag?(:x86_64) %}
      help.should contain("sse2")
    {% end %}
  end
end
