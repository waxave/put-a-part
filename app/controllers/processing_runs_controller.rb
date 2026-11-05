class ProcessingRunsController < ApplicationController
  def index
    @page = [ [ params[:page].to_i, 1 ].max, 1_000_000 ].min
    runs = ProcessingRun.order(created_at: :desc, id: :desc).offset((@page - 1) * 100).limit(101).with_attached_input_file.to_a
    @has_next_page = runs.length > 100
    @runs = runs.first(100)
  end

  def show
    @run = ProcessingRun.find(params[:id])
    @page = [ [ params[:page].to_i, 1 ].max, 1_000_000 ].min
    records = @run.processing_records.order(:source_sheet, :source_row, :id).offset((@page - 1) * 100).limit(101).to_a
    @has_next_page = records.length > 100
    @records = records.first(100)
    @issues = @run.processing_issues.includes(:processing_record).order(:created_at, :id).limit(100)
    @selected_release = KnowledgeRelease.find_by(id: params[:knowledge_release_id]) if params[:knowledge_release_id].present?
  end

  def create
    run = Etl::SubmitRun.new.call(params[:input_file])
    redirect_to processing_run_path(run), notice: t("notices.queued"), status: :see_other
  rescue Etl::SubmitRun::InvalidUpload => error
    redirect_to processing_runs_path, alert: error.message, status: :see_other
  end

  def download
    run = ProcessingRun.find(params[:id])
    return head :not_found unless run.status.in?(%w[completed completed_with_warnings]) && run.output_file.attached?

    send_data run.output_file.download, filename: run.output_file.filename.to_s, type: run.output_file.content_type, disposition: :attachment
  end

  def cancel
    run = ProcessingRun.find(params[:id])
    if run.request_cancellation!
      redirect_to processing_run_path(run), notice: t("notices.cancellation_requested"), status: :see_other
    else
      redirect_to processing_run_path(run), alert: t("notices.already_finished"), status: :see_other
    end
  end

  def reprocess
    run = Etl::ReprocessRun.new.call(ProcessingRun.find(params[:id]), knowledge_release_id: params[:knowledge_release_id])
    redirect_to processing_run_path(run), notice: t("notices.reprocess_queued"), status: :see_other
  rescue Etl::ReprocessRun::InvalidRun => error
    redirect_to processing_run_path(params[:id]), alert: error.message, status: :see_other
  end
end
