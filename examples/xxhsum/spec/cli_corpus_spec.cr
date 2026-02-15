require "./spec_helper"
require "./support/cli_corpus_helper"

describe "XXHSum CLI cucumber corpus" do
  CLICorpusHelper.load_cases.each do |kase|
    it kase.name do
      result = CLICorpusHelper.run_case(kase)

      result.exit_code.should eq(kase.expected_exit)
      CLICorpusHelper.assert_snapshot(kase.stdout_snapshot, result.stdout)
      CLICorpusHelper.assert_snapshot(kase.stderr_snapshot, result.stderr)
    end
  end
end
