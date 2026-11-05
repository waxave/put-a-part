require "digest"
require "sqlite3"

module Automotive
  module Knowledge
    module VehicleReferenceSources
      class SqliteSource
        class InvalidArtifact < StandardError; end

        def initialize(path:)
          @path = File.expand_path(path.to_s)
          raise InvalidArtifact, "SQLite artifact does not exist: #{@path}" unless File.file?(@path)

          @database = SQLite3::Database.new(@path, readonly: true)
          @database.results_as_hash = true
          integrity = @database.get_first_value("PRAGMA quick_check")
          raise InvalidArtifact, "SQLite quick_check failed: #{integrity}" unless integrity == "ok"
        rescue SQLite3::Exception => error
          raise InvalidArtifact, "Cannot open SQLite artifact: #{error.message}"
        end

        attr_reader :path

        def sha256
          @sha256 ||= Digest::SHA256.file(path).hexdigest
        end

        def close
          @database.close unless @database.closed?
        end

        private

        attr_reader :database

        def table_names
          database.execute("SELECT name FROM sqlite_master WHERE type = 'table'").map { |row| row["name"] || row[0] }
        end

        def require_tables!(*tables)
          missing = tables - table_names
          raise InvalidArtifact, "SQLite schema is missing tables: #{missing.join(', ')}" if missing.any?
        end
      end
    end
  end
end
