namespace :automotive_knowledge do
  desc "Backfill existing run evidence into normalized automotive knowledge tables"
  task backfill: :environment do
    batch_size = ENV.fetch("BATCH_SIZE", "200")
    result = CatalogIntelligence::BackfillAutomotiveKnowledge.new(batch_size: batch_size).call
    puts "Backfilled #{result.fetch(:records)} records and #{result.fetch(:observations)} observations."
  end
end
