class RenameVehicleGenerationAttributes < ActiveRecord::Migration[8.1]
  def change
    rename_column :vehicle_generations, :attributes, :source_attributes
  end
end
