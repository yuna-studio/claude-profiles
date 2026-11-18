class Ccp < Formula
  desc "Several Claude Code accounts on one computer, with live usage per account"
  homepage "https://github.com/yuna-studio/claude-profiles"
  url "https://github.com/yuna-studio/claude-profiles/releases/download/v0.5.0/ccp"
  sha256 "10d385f425c38175a40fec47c16b354a5fae45d2c4ebe97d33e0d902893e78a4"
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
