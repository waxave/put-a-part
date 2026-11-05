class AddRecordIssueUniqueness < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :processing_issues, [ :processing_record_id, :stage, :code ],
      unique: true, where: "processing_record_id IS NOT NULL", algorithm: :concurrently,
      name: "index_processing_issues_on_record_stage_code"
  end
end
