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
    help.should contain("--simd BACKEND")
    help.should contain("scalar")

    {% if flag?(:aarch64) %}
      help.should contain("neon")
    {% elsif flag?(:x86_64) %}
      help.should contain("sse2")
    {% end %}
  end

  it "parses --simd with space-separated value" do
    opts = XXHSum::CLI::Options.parse(["--simd", "scalar"])
    opts.simd_mode.should eq("scalar")
  end

  it "parses --simd with equals-separated value" do
    opts = XXHSum::CLI::Options.parse(["--simd=scalar"])
    opts.simd_mode.should eq("scalar")
  end

  it "parses platform-specific --simd backend" do
    {% if flag?(:aarch64) %}
      opts = XXHSum::CLI::Options.parse(["--simd", "neon"])
      opts.simd_mode.should eq("neon")
    {% elsif flag?(:x86_64) %}
      opts = XXHSum::CLI::Options.parse(["--simd", "sse2"])
      opts.simd_mode.should eq("sse2")
    {% else %}
      opts = XXHSum::CLI::Options.parse(["--simd", "scalar"])
      opts.simd_mode.should eq("scalar")
    {% end %}
  end

  it "rejects unknown SIMD backend name" do
    # invalid_backend is not in any platform's simd_backends list
    XXHSum::CLI::Options.simd_backends.should_not contain("invalid_backend")
    XXHSum::CLI::Options.simd_backends.should_not be_empty
  end
end
