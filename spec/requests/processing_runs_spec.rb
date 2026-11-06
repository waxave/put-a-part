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

  it "keeps individual extraction details and displays the fallback result JSON" do
    run = ProcessingRun.create!(status: "completed", stage: "completed", processed_records: 1, total_records: 1)
    record = run.processing_records.create!(source_sheet: "Origen", source_row: 2, source_sku: "X-1",
      normalized_product: { "sku" => "X-1", "extraction_fallback" => { "part_number" => "X-1", "applications" => [] } },
      facts: [ { "type" => "vehicle_candidate", "value" => { "make" => "Dodge", "model" => "Durango" },
        "raw_value" => "CHRYSLER DURANGO", "confidence" => "candidate", "parser_id" => "vehicle_description" } ])
    record.enrichment_requests.create!(source_key: "autofacts", status: "completed",
      result_data: { "reason_code" => "match_found", "reason" => "Exact part number and brand candidate found.",
        "autofacts_result" => { "part_number" => "X-1", "category" => { "name" => "Engine" } } })

    get "/processing_runs/#{run.id}"

    expect(response.body).to include("CHRYSLER DURANGO", "Candidato construido con datos extraídos (estructura Autofacts Part)",
      "&quot;part_number&quot;:", "Resultado original de Autofacts (formato de la biblioteca)",
      "Se encontró un candidato con número de parte y marca exactos.")
    expect(response.body).not_to include("Exact part number and brand candidate found.")
  end

  it "keeps the download unavailable while Autofacts research is running" do
    run = ProcessingRun.create!(status: "processing", stage: "researching")

    get "/processing_runs/#{run.id}"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Buscando datos de las piezas y preparando el archivo final")
    expect(response.body).not_to include("Descargar XLSX")

    get "/processing_runs/#{run.id}/download"
    expect(response).to have_http_status(:not_found)
  end

  it "does not expose API endpoints" do
    get "/api/v1/processing_runs"

    expect(response).to have_http_status(:not_found)
  end
end
