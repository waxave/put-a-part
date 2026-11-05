module Automotive
  module Knowledge
    module VehicleReferenceSources
      class Vehiclesdb < SqliteSource
        SOURCE_KEY = "vehiclesdb_catalog"
        LICENSE = "CC-BY-4.0"
        ATTRIBUTION = "Vehicle data by VehiclesDB (https://vehiclesdb.com), CC-BY 4.0. Upstream register attribution notices in the pinned ATTRIBUTION.md also apply."
        NORMALIZER_VERSION = "vehiclesdb-dist-sqlite-v1"

        def initialize(**)
          super
          require_tables!("makes", "models", "availability", "popularity", "meta")
          @meta = database.execute("SELECT key, value FROM meta").to_h { |row| [ row["key"], row["value"] ] }
          raise InvalidArtifact, "VehiclesDB catalog must declare CC-BY-4.0" unless @meta["license"] == LICENSE
        end

        def source_key = SOURCE_KEY
        def source_version = ENV.fetch("VEHICLESDB_SOURCE_VERSION", "d0e40c9661e36931089db1213ac383d2d7ba5a7a:#{@meta.fetch('version')}")
        def license_identifier = LICENSE
        def attribution
          attribution_path = ENV["VEHICLESDB_ATTRIBUTION_PATH"] || [
            File.join(File.dirname(path), "ATTRIBUTION.md"),
            File.expand_path("../ATTRIBUTION.md", File.dirname(path))
          ].find { |candidate| File.file?(candidate) }
          raise InvalidArtifact, "VehiclesDB ATTRIBUTION.md is required; set VEHICLESDB_ATTRIBUTION_PATH" unless attribution_path && File.file?(attribution_path)

          "#{ATTRIBUTION}\n\nUpstream attribution notices from the pinned repository:\n#{File.read(attribution_path)}"
        end
        def normalizer_version = NORMALIZER_VERSION
        def schema_version = "catalog-3/dist-2"

        def each_record
          return enum_for(__method__) unless block_given?

          database.execute("SELECT id, kind, name FROM makes ORDER BY kind, id").each do |row|
            yield record("make", "#{row['kind']}:#{row['id']}", row,
              kind: row["kind"], make_name: row["name"], make_source_id: row["id"])
          end

          database.execute(<<~SQL).each do |row|
            SELECT models.id, models.kind, models.make_id, models.slug, models.name, models.body_types,
                   models.regions, models.global_popularity_decile, models.mass_popularity_decile,
                   makes.name AS make_name
            FROM models JOIN makes ON makes.id = models.make_id AND makes.kind = models.kind
            ORDER BY models.kind, models.id
          SQL
            yield record("model", "#{row['kind']}:#{row['id']}", row,
              kind: row["kind"], make_name: row["make_name"], model_name: row["name"],
              make_source_id: row["make_id"], model_source_id: row["id"], slug: row["slug"],
              body_types: split_values(row["body_types"]), regions: split_values(row["regions"]),
              global_popularity_decile: row["global_popularity_decile"],
              mass_popularity_decile: row["mass_popularity_decile"])
          end

          database.execute(<<~SQL).each do |row|
            SELECT availability.model_id, availability.kind, availability.country,
                   availability.evidence, availability.source, models.name AS model_name,
                   makes.name AS make_name
            FROM availability
            JOIN models ON models.id = availability.model_id AND models.kind = availability.kind
            JOIN makes ON makes.id = models.make_id AND makes.kind = models.kind
            ORDER BY availability.kind, availability.model_id, availability.country, availability.source
          SQL
            yield record("availability", "#{row['kind']}:#{row['model_id']}:#{row['country']}:#{row['source']}", row,
              kind: row["kind"], make_name: row["make_name"], model_name: row["model_name"],
              model_source_id: row["model_id"], country: row["country"], evidence: row["evidence"], source: row["source"])
          end

          database.execute(<<~SQL).each do |row|
            SELECT popularity.model_id, popularity.kind, popularity.country, popularity.rank,
                   popularity.decile, popularity.confidence, models.name AS model_name,
                   makes.name AS make_name
            FROM popularity
            JOIN models ON models.id = popularity.model_id AND models.kind = popularity.kind
            JOIN makes ON makes.id = models.make_id AND makes.kind = models.kind
            ORDER BY popularity.kind, popularity.model_id, popularity.country
          SQL
            yield record("popularity", "#{row['kind']}:#{row['model_id']}:#{row['country']}", row,
              kind: row["kind"], make_name: row["make_name"], model_name: row["model_name"],
              model_source_id: row["model_id"], country: row["country"], rank: row["rank"], decile: row["decile"],
              confidence: row["confidence"])
          end
        end

        private

        def record(type, id, raw, normalized)
          { type: type, source_id: "#{type}:#{id}", raw: raw, normalized: normalized }
        end

        def split_values(value)
          value.to_s.split("|", -1).reject(&:empty?)
        end
      end
    end
  end
end
