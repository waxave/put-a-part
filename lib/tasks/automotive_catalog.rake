namespace :automotive_catalog do
  desc "Rebuild the PostgreSQL full-text index for the current vehicle reference catalog"
  task rebuild_vehicle_search: :environment do
    count = Automotive::Knowledge::RebuildVehicleSearchIndex.new.call
    puts "Indexed #{count} vehicle catalog entries"
  end

  desc "Import a local gor3a or VehiclesDB SQLite catalog (dry-run unless APPLY=true)"
  task import: :environment do
    source = ENV.fetch("SOURCE") { abort "Set SOURCE=gor3a or SOURCE=vehiclesdb" }
    path = ENV.fetch("SQLITE_PATH") { abort "Set SQLITE_PATH to the local SQLite file" }
    result = Automotive::Knowledge::ImportVehicleCatalogSource.new(source: source, path: path,
      apply: ENV["APPLY"] == "true", batch_size: ENV.fetch("BATCH_SIZE", 500)).call
    puts "#{result[:applied] ? 'Imported' : 'Validated (dry run)'} #{result[:source]} #{result[:version]}: #{result[:counts].inspect}"
  rescue Automotive::Knowledge::VehicleReferenceSources::SqliteSource::InvalidArtifact,
    Automotive::Knowledge::ImportVehicleCatalogSource::InvalidRecord, ArgumentError => error
    abort error.message
  end
end
