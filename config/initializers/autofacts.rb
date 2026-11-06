# frozen_string_literal: true

# Use the gem's shared resolver (AUTOFACTS_DATABASE_PATH, then config/autofacts.yml,
# then its default). Resolve relative paths from the Rails application root.
configured_path = Dir.chdir(Rails.root) { Autofacts.database_path }
path = Pathname.new(configured_path)
Autofacts.database_path = path.absolute? ? path.to_s : Rails.root.join(path).to_s

# Build a client on demand:
#   client = Autofacts::Client.new
