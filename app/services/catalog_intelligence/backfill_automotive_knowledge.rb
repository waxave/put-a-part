module CatalogIntelligence
  class BackfillAutomotiveKnowledge
    def self.call(batch_size: 200)
      new(batch_size: batch_size).call
    end

    def initialize(batch_size: 200)
      @batch_size = Integer(batch_size)
      raise ArgumentError, "Batch size must be positive" unless @batch_size.positive?
    end

    def call
      counts = { records: 0, observations: 0 }
      ProcessingRecord.find_in_batches(batch_size: @batch_size) do |batch|
        batch.each do |record|
          ProcessingRecord.transaction do
            PersistExtraction.call(record)
            record.catalog_observations.find_each do |observation|
              PersistObservation.call(observation)
              counts[:observations] += 1
            end
          end
          counts[:records] += 1
        end
      end
      counts
    end
  end
end
