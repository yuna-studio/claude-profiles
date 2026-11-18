class Ccp < Formula
  desc "Several Claude Code accounts on one computer, with live usage per account"
  homepage "https://github.com/yuna-studio/claude-profiles"
  url "https://github.com/yuna-studio/claude-profiles/releases/download/v0.5.0/ccp"
  sha256 "71d65072ef2a91fd5815021984dbd2d1fd21276b960cbfa08579f007db04fa9d"
  version "0.5.0"
  license "MIT"

  def install
    bin.install "ccp"
  end

  def caveats
    <<~EOS
      Sign in once per account:   ccp add
      See every account's limits: ccp top
      Move on when one is full:   ccp service start
      Optional, so plain `claude` follows your accounts:
        echo 'eval "$(ccp init zsh)"' >> ~/.zshrc
    EOS
  end

  test do
    assert_match "ccp #{version}", shell_output("#{bin}/ccp --version")
  end
end
