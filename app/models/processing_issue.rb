class ProcessingIssue < ApplicationRecord
  belongs_to :processing_run
  belongs_to :processing_record, optional: true
end
