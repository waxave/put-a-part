require "spec_helper"
require "open3"
require "tmpdir"
require "rbconfig"

RSpec.describe "bin/dev" do
  it "starts the development process supervisor with the web and ETL worker" do
    Dir.mktmpdir do |directory|
      bundle = File.join(directory, "bundle")
      File.write(bundle, "#!/bin/sh\nprintf '%s\\n' \"$@\"\n")
      File.chmod(0o755, bundle)
      output, _error, status = Open3.capture3({ "PATH" => "#{directory}:#{ENV.fetch('PATH')}" }, RbConfig.ruby, "bin/dev")

      expect(status).to be_success
      expect(output.lines.map(&:strip)).to eq([ "exec", "foreman", "start", "-f", "Procfile.dev", "-p", "3000" ])
      procfile = File.read("Procfile.dev")
      expect(procfile).to match(/^web:.*rails server/)
      expect(procfile).to match(/^worker:.*sidekiq.*config\/sidekiq.yml/)
    end
  end
end
