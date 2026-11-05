class LinkVehicleRecordsToImports < ActiveRecord::Migration[8.1]
  def change
    add_reference :vehicle_reference_records, :vehicle_reference_import, foreign_key: true
  end
end
