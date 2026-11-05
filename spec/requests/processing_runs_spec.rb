require "rails_helper"

RSpec.describe "Workbook UI", type: :request do
  include ActiveJob::TestHelper

  let(:fixture) { Rails.root.join("spec/fixtures/files/input_prueba.xlsx") }

  it "opens without authentication in Spanish by default" do
    get "/"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('<html lang="es">', "Espacio de trabajo", "Español", "English")
  end

  it "switches and remembers the selected language" do
    patch "/locale/en", headers: { "HTTP_REFERER" => "http://www.example.com/" }
    expect(response).to have_http_status(:see_other)

    get "/"
    expect(response.body).to include('<html lang="en">', "Workbook workspace", "Choose workbook")

    patch "/locale/es", headers: { "HTTP_REFERER" => "http://www.example.com/" }
    get "/"
    expect(response.body).to include('<html lang="es">', "Elegir archivo")
  end

  it "queues a valid workbook from the unauthenticated HTML form" do
    upload = Rack::Test::UploadedFile.new(fixture, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")

    expect do
      post "/processing_runs", params: { input_file: upload }
    end.to have_enqueued_job(ProcessCatalogJob).on_queue("etl")

    expect(response).to have_http_status(:see_other)
    expect(response.location).to include("/processing_runs/")
  end

  it "shows upload errors in the currently selected language" do
    upload = Tempfile.new([ "invalid", ".xlsx" ])
    upload.write("not a workbook")
    upload.rewind

    patch "/locale/es", headers: { "HTTP_REFERER" => "http://www.example.com/" }
    post "/processing_runs", params: { input_file: Rack::Test::UploadedFile.new(upload.path, "application/octet-stream") }

    expect(response).to have_http_status(:see_other)
    follow_redirect!
    expect(response.body).to include("El archivo no es un libro XLSX válido.")
  ensure
    upload&.close!
  end

  it "renders a run detail page without authentication" do
    run = ProcessingRun.create!(status: "completed", stage: "completed", processed_records: 1, total_records: 1)

    get "/processing_runs/#{run.id}"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Procesamiento", "Registros")
  end

  it "does not expose API endpoints" do
    get "/api/v1/processing_runs"

    expect(response).to have_http_status(:not_found)
  end
end
