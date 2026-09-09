require "pathname"

directory = Pathname(ARGV.fetch(0))
formula = (directory/"homebrew/Formula/continuous.rb").read
formula = formula.gsub(%r{https://github.com/continuous-labs-ai/cli/releases/download/[^/]+/(continuous_[A-Za-z0-9_]+\.tar\.gz)}) do
  "file://#{directory}/#{Regexp.last_match(1)}"
end
Pathname(ARGV.fetch(1)).write(formula)
