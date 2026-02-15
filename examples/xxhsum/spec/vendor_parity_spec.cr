require "./spec_helper"
require "./support/cli_corpus_helper"
require "./support/vendor_parity_helper"

describe "Vendor Parity — cr-xxhash vs. vendor xxhsum" do
  # Load all corpus cases for validation
  cases = VendorParityHelper.load_cases

  # Cases to skip in vendor parity testing
  # (they test Crystal-specific behavior or are not applicable to C implementation)
  skip_patterns = [
    # These test implementation-specific help output formatting
    "help",
    # No-args with TTY is Crystal-specific behavior
    "tty",
  ]

  # Filter cases: only test baseline parity cases (not mutation or extreme edge cases initially)
  baseline_cases = cases.select do |kase|
    !skip_patterns.any? { |pattern| kase.name.downcase.includes?(pattern) }
  end

  baseline_cases.each do |kase|
    it "#{kase.name} (exit code + stdout/stderr parity)" do
      # Run both implementations
      vendor_result = VendorParityHelper.run_vendor_case(kase)
      crystal_result = VendorParityHelper.run_crystal_case(kase)

      # Compare outputs
      parity = VendorParityHelper.compare_outputs(vendor_result, crystal_result, kase.name)

      # Validate parity
      unless parity.exit_code_match
        puts "\n  Exit code mismatch in #{kase.name}"
        puts "    Vendor:  #{parity.exit_code_expected}"
        puts "    Crystal: #{parity.exit_code_actual}"
      end
      parity.exit_code_match.should be_true

      unless parity.stdout_match
        puts "\n  Stdout mismatch in #{kase.name}"
        puts "    Vendor:  #{parity.stdout_expected.inspect}"
        puts "    Crystal: #{parity.stdout_actual.inspect}"
      end
      parity.stdout_match.should be_true

      unless parity.stderr_match
        puts "\n  Stderr mismatch in #{kase.name}"
        puts "    Vendor:  #{parity.stderr_expected.inspect}"
        puts "    Crystal: #{parity.stderr_actual.inspect}"
      end
      parity.stderr_match.should be_true
    end
  end

  # After all tests, generate comprehensive parity report
  after_all do
    # Run all baseline cases and generate report
    results = baseline_cases.map do |kase|
      vendor_result = VendorParityHelper.run_vendor_case(kase)
      crystal_result = VendorParityHelper.run_crystal_case(kase)
      VendorParityHelper.compare_outputs(vendor_result, crystal_result, kase.name)
    end

    report = VendorParityHelper.generate_report(results)
    puts "\n" + report

    # Optionally save report to file
    report_path = File.expand_path("../parity_report.txt", __DIR__)
    File.write(report_path, report)
  end
end
