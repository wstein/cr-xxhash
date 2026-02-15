require "./spec_helper"
require "./support/cli_corpus_helper"

describe "Snapshot normalization helper" do
  it "converts CRLF to LF and normalizes lone CR" do
    crlf = "line1\r\nline2\r\n"
    lf = "line1\nline2\n"

    CLICorpusHelper.normalize_eol(crlf).should eq(lf)
    CLICorpusHelper.normalize_eol("line\ronly\r").should eq("line\nonly\n")
  end

  it "trims trailing spaces/tabs on each line and preserves trailing newline state" do
    s = "a  \t \nline2  \nno-nl"
    normalized = CLICorpusHelper.normalize_eol(s)

    # trailing spaces removed, final newline preserved only if originally present
    normalized.includes?("a\n").should be_true
    normalized.includes?("line2\n").should be_true
    normalized.ends_with?("no-nl").should be_true # normalize_eol preserves trailing-newline state (none here)
  end
end
