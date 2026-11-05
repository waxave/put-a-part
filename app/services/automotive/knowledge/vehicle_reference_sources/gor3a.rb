module Automotive
  module Knowledge
    module VehicleReferenceSources
      class Gor3a < SqliteSource
        SOURCE_KEY = "gor3a_vehicle_makes_models"
        LICENSE = "ODbL-1.0"
        ATTRIBUTION = "Data by vehicle-makes-models (https://github.com/gor3a/vehicle-makes-models), compiled in part from autoevolution.com (https://www.autoevolution.com/); adapted into this canonical catalog. ODbL 1.0 applies."
        NORMALIZER_VERSION = "gor3a-sqlite-v1"

        def initialize(**)
          super
          require_tables!("makes", "models", "generations", "engines", "engine_specs")
        end

        def source_key = SOURCE_KEY
        def source_version = ENV.fetch("GOR3A_SOURCE_VERSION", "ee99776470a45214bf524cdfe22e5dbf4bd67f93")
        def license_identifier = LICENSE
        def attribution = ATTRIBUTION
        def normalizer_version = NORMALIZER_VERSION
        def schema_version = "gor3a-sqlite-1"

        def each_record
          return enum_for(__method__) unless block_given?

          database.execute('SELECT id, "group", name, country FROM makes ORDER BY id').each do |make|
            yield record("make", make["id"], make,
              kind: "car", make_name: make["name"], source_group: make["group"], country: make["country"])
          end

          database.execute(<<~SQL) do |row|
            SELECT models.id, models.make_id, models.name, models.year_start, models.year_end,
                   makes.name AS make_name
            FROM models JOIN makes ON makes.id = models.make_id ORDER BY models.id
          SQL
            yield record("model", row["id"], row,
              kind: "car", make_name: row["make_name"], model_name: row["name"],
              make_source_id: row["make_id"], model_source_id: row["id"],
              year_start: valid_year(row["year_start"]), year_end: valid_year(row["year_end"]))
          end

          database.execute(<<~SQL).each do |row|
            SELECT generations.id, generations.model_id, generations.name, generations.year_start,
                   generations.year_end, generations.body_type, models.name AS model_name,
                   makes.name AS make_name
            FROM generations
            JOIN models ON models.id = generations.model_id
            JOIN makes ON makes.id = models.make_id
            ORDER BY generations.id
          SQL
            yield record("generation", row["id"], row,
              kind: "car", make_name: row["make_name"], model_name: row["model_name"],
              model_source_id: row["model_id"],
              generation_name: row["name"], year_start: valid_year(row["year_start"]),
              year_end: valid_year(row["year_end"]), body_type: clean(row["body_type"]))
          end

          each_engine do |engine|
            yield record("engine", engine.fetch("id"), engine,
              kind: "car", make_name: engine.fetch("make_name"), model_name: engine.fetch("model_name"),
              model_source_id: engine.fetch("model_id"), generation_source_id: engine.fetch("generation_id"),
              generation_name: engine.fetch("generation_name"), engine_name: engine.fetch("label"),
              fuel_type: clean(engine["fuel_type"]), cylinder_count: positive_integer(engine["cylinders"]),
              displacement_cc: positive_integer(engine["displacement_cc"]), power_hp: engine["power_hp"],
              torque_nm: engine["torque_nm"], transmission: clean(engine["transmission"]),
              drivetrain: clean(engine["drivetrain"]), specifications: engine["specs"])
          end
        end

        private

        def each_engine
          previous_id = nil
          current = nil
          database.execute(<<~SQL) do |row|
            SELECT engines.id, engines.generation_id, engines.label, engines.fuel_type,
                   engines.cylinders, engines.displacement_cc, engines.power_hp, engines.torque_nm,
                   engines.transmission, engines.drivetrain, engines.zero_to_100_s,
                   engines.top_speed_kmh, engines.fuel_economy_combined_l100, engines.length_mm,
                   engines.width_mm, engines.height_mm, engines.wheelbase_mm, engines.curb_weight_kg,
                   generations.name AS generation_name, models.id AS model_id, models.name AS model_name, makes.name AS make_name,
                   engine_specs.key AS spec_key, engine_specs.value AS spec_value
            FROM engines
            JOIN generations ON generations.id = engines.generation_id
            JOIN models ON models.id = generations.model_id
            JOIN makes ON makes.id = models.make_id
            LEFT JOIN engine_specs ON engine_specs.engine_id = engines.id
            ORDER BY engines.id, engine_specs.id
          SQL
            if previous_id && row["id"] != previous_id
              yield current
              current = nil
            end
            current ||= {
              "id" => row["id"], "generation_id" => row["generation_id"], "label" => row["label"],
              "fuel_type" => row["fuel_type"], "cylinders" => row["cylinders"],
              "displacement_cc" => row["displacement_cc"], "power_hp" => row["power_hp"],
              "torque_nm" => row["torque_nm"], "transmission" => row["transmission"],
              "drivetrain" => row["drivetrain"], "zero_to_100_s" => row["zero_to_100_s"],
              "top_speed_kmh" => row["top_speed_kmh"],
              "fuel_economy_combined_l100" => row["fuel_economy_combined_l100"],
              "length_mm" => row["length_mm"], "width_mm" => row["width_mm"], "height_mm" => row["height_mm"],
              "wheelbase_mm" => row["wheelbase_mm"], "curb_weight_kg" => row["curb_weight_kg"],
              "model_id" => row["model_id"],
              "generation_name" => row["generation_name"], "model_name" => row["model_name"],
              "make_name" => row["make_name"], "specs" => []
            }
            current["specs"] << { "key" => row["spec_key"], "value" => row["spec_value"] } if row["spec_key"]
            previous_id = row["id"]
          end
          yield current if current
        end

        def record(type, id, raw, normalized)
          issues = %i[year_start year_end].filter_map do |field|
            value = raw[field.to_s]
            "invalid_#{field}: #{value}" if !value.nil? && normalized[field].nil?
          end
          { type: type, source_id: "#{type}:#{id}", raw: raw, normalized: normalized, validation_issues: issues }
        end

        def clean(value)
          value.to_s.strip.presence
        end

        def valid_year(value)
          year = Integer(value, exception: false)
          year if year && (1886..2100).cover?(year)
        end

        def positive_integer(value)
          number = Integer(value, exception: false)
          number if number&.positive?
        end
      end
    end
  end
end
