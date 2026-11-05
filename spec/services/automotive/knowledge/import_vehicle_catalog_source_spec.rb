require "rails_helper"
require "tmpdir"

RSpec.describe Automotive::Knowledge::ImportVehicleCatalogSource do
  around do |example|
    Dir.mktmpdir("vehicle-catalog-spec") do |directory|
      @directory = directory
      example.run
    end
  end

  it "dry-runs and idempotently imports VehiclesDB's kind-scoped taxonomy and evidence" do
    FileUtils.mkdir_p(File.join(@directory, "dist"))
    File.write(File.join(@directory, "ATTRIBUTION.md"), "Fixture upstream notices")
    path = File.join(@directory, "dist", "catalog.sqlite")
    db = SQLite3::Database.new(path)
    db.execute_batch(<<~SQL)
      CREATE TABLE meta (key TEXT, value TEXT);
      INSERT INTO meta VALUES ('version', 'test-1'), ('license', 'CC-BY-4.0');
      CREATE TABLE makes (id TEXT, kind TEXT, name TEXT, PRIMARY KEY (id, kind));
      CREATE TABLE models (id TEXT, kind TEXT, make_id TEXT, slug TEXT, name TEXT, body_types TEXT,
        regions TEXT, global_popularity_decile INTEGER, mass_popularity_decile INTEGER, PRIMARY KEY (id, kind));
      CREATE TABLE availability (model_id TEXT, kind TEXT, country TEXT, evidence TEXT, source TEXT);
      CREATE TABLE popularity (model_id TEXT, kind TEXT, country TEXT, rank INTEGER, decile INTEGER, confidence TEXT);
      INSERT INTO makes VALUES ('fixture', 'car', 'Fixture Motors');
      INSERT INTO models VALUES ('fixture/roadster', 'car', 'fixture', 'roadster', 'Roadster', 'coupe', 'na', 2, 1);
      INSERT INTO models VALUES ('fixture/blank', 'car', 'fixture', 'blank', '', NULL, NULL, NULL, NULL);
      INSERT INTO availability VALUES ('fixture/roadster', 'car', 'us', 'approval', 'fixture-source');
      INSERT INTO popularity VALUES ('fixture/roadster', 'car', 'us', 1, 1, 'measured');
    SQL
    db.close

    dry_run = described_class.new(source: "vehiclesdb", path: path).call
    expect(dry_run[:applied]).to be(false)
    expect(dry_run[:counts][:total]).to eq(5)
    expect(dry_run[:counts][:with_issues]).to eq(1)
    expect(VehicleReferenceDataset.count).to eq(0)

    original_created_at = nil
    2.times do |iteration|
      result = described_class.new(source: "vehiclesdb", path: path, apply: true, batch_size: 2).call
      expect(result[:counts][:total]).to eq(5)
      original_created_at ||= VehicleReferenceRecord.order(:id).first&.created_at
      expect(VehicleReferenceRecord.order(:id).first.created_at).to eq(original_created_at) if iteration.positive?
    end

    expect(VehicleMake.count).to eq(1)
    expect(VehicleModel.count).to eq(1)
    expect(VehicleModel.first.vehicle_kind).to eq("car")
    expect(VehicleReferenceRecord.count).to eq(5)
    expect(VehicleReferenceImport.count).to eq(2)
    expect(VehicleReferenceDataset.first.attribution).to include("Fixture upstream notices")
    expect(VehicleReferenceRecord.find_by!(source_record_id: "model:car:fixture/blank").resolution_status).to eq("rejected")
    expect(VehicleReferenceRecord.find_by!(record_type: "availability").source_parent_id).to eq("fixture/roadster")
    Automotive::Knowledge::RebuildVehicleSearchIndex.new.call
    expect(VehicleSearchEntry.full_text("coupe").pluck(:entry_type)).to include("model")
  end

  it "preserves gor3a's generation, typed engine data and raw engine specifications" do
    path = File.join(@directory, "gor3a.sqlite")
    db = SQLite3::Database.new(path)
    db.execute_batch(<<~SQL)
      CREATE TABLE makes (id INTEGER, "group" TEXT, name TEXT, country TEXT);
      CREATE TABLE models (id INTEGER, make_id INTEGER, name TEXT, year_start INTEGER, year_end INTEGER);
      CREATE TABLE generations (id INTEGER, model_id INTEGER, name TEXT, year_start INTEGER, year_end INTEGER, body_type TEXT);
      CREATE TABLE engines (id INTEGER, generation_id INTEGER, label TEXT, fuel_type TEXT, cylinders INTEGER,
        displacement_cc INTEGER, power_hp REAL, torque_nm REAL, transmission TEXT, drivetrain TEXT,
        zero_to_100_s REAL, top_speed_kmh REAL, fuel_economy_combined_l100 REAL, length_mm INTEGER,
        width_mm INTEGER, height_mm INTEGER, wheelbase_mm INTEGER, curb_weight_kg INTEGER);
      CREATE TABLE engine_specs (id INTEGER, engine_id INTEGER, key TEXT, value TEXT);
      INSERT INTO makes VALUES (1, 'fixture', 'Fixture Motors', NULL);
      INSERT INTO models VALUES (1, 1, 'Roadster', 2020, NULL);
      INSERT INTO generations VALUES (1, 1, 'Roadster (2020)', 2020, NULL, 'coupe');
      INSERT INTO engines VALUES (1, 1, '2.0L 6MT RWD', 'Gasoline', 4, 1998, 200, 250, '6-speed manual', 'RWD', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
      INSERT INTO engines VALUES (2, 1, '2.0L 6MT RWD', 'Gasoline', 4, 1998, 210, 250, '6-speed manual', 'RWD', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
      INSERT INTO engine_specs VALUES (1, 1, 'ENGINE / Fuel', 'Gasoline');
    SQL
    db.close

    result = described_class.new(source: "gor3a", path: path, apply: true).call

    expect(result[:counts]).to include("make" => 1, "model" => 1, "generation" => 1, "engine" => 2, :total => 5)
    generation = VehicleGeneration.sole
    engine = VehicleEngineVariant.sole
    expect(generation.year_start).to eq(2020)
    expect(generation.year_end).to be_nil
    expect(engine.cylinder_count).to eq(4)
    expect(engine.specifications).to include("engine_specs" => [ { "key" => "ENGINE / Fuel", "value" => "Gasoline" } ])
    expect(VehicleReferenceRecord.find_by!(source_record_id: "engine:1").raw_record).to include("specs" => [
      { "key" => "ENGINE / Fuel", "value" => "Gasoline" }
    ])
    conflicting_record = VehicleReferenceRecord.find_by!(source_record_id: "engine:2")
    expect(conflicting_record.resolution_status).to eq("conflict")
    expect(conflicting_record.validation_issues).to include(a_string_matching("canonical_conflict_power_hp"))
    expect(conflicting_record.source_parent_id).to eq("1")
    Automotive::Knowledge::RebuildVehicleSearchIndex.new.call
    expect(VehicleSearchEntry.full_text("2020 coupe").pluck(:entry_type)).to include("generation")
    expect(VehicleSearchEntry.full_text("Gasoline").pluck(:entry_type)).to include("engine")
  end
end
