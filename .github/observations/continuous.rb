cask "continuous" do
  version "0.1.0"

  on_arm do
    sha256 "6013741bc4b038d6bf56dc685c334c11420cbc610c4623160681a0cc8ff6c5b4"
    url "https://github.com/continuous-labs-ai/cli/releases/download/v#{version}/continuous_Darwin_arm64.tar.gz"
  end
  on_intel do
    sha256 "7510330a6082d520b3622b23fe64fa2888c8ed773a62e313f96f2e1f613c020e"
    url "https://github.com/continuous-labs-ai/cli/releases/download/v#{version}/continuous_Darwin_x86_64.tar.gz"
  end

  name "Continuous"
  desc "Continuous Simulation CLI"
  homepage "https://github.com/continuous-labs-ai/cli"

  binary "continuous"
end
