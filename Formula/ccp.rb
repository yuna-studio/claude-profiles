class Ccp < Formula
  desc "Several Claude Code accounts on one computer, with live usage per account"
  homepage "https://github.com/yuna-studio/claude-profiles"
  url "https://github.com/yuna-studio/claude-profiles/releases/download/v0.4.0/ccp"
  sha256 "SHA256_PLACEHOLDER"
  version "0.4.0"
  license "MIT"

  def install
    bin.install "ccp"
  end

  def caveats
    <<~EOS
      Sign in once per account:   ccp add
      See every account's limits: ccp top
      Optional, so plain `claude` follows your accounts:
        echo 'eval "$(ccp init zsh)"' >> ~/.zshrc
    EOS
  end

  test do
    assert_match "ccp #{version}", shell_output("#{bin}/ccp --version")
  end
end
