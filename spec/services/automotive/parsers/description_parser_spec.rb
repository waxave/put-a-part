require "spec_helper"
require_relative "../../../../app/services/automotive/parsers/description_parser"

RSpec.describe Automotive::Parsers::DescriptionParser do
  it "extracts independent engine and application candidates from a supplier description" do
    facts = described_class.new.call("NISSAN PICK UP 4 CIL 2.4 KA24E SOHC 12 VAL 89/03")

    expect(facts).to include(
      a_hash_including(type: "engine_code_candidate", value: "KA24E", raw_value: "KA24E"),
      a_hash_including(type: "cylinder_count_candidate", value: 4, raw_value: "4 CIL"),
      a_hash_including(type: "displacement_liters_candidate", value: 2.4, raw_value: "2.4"),
      a_hash_including(type: "valve_count_candidate", value: 12, raw_value: "12 VAL"),
      a_hash_including(type: "camshaft_candidate", value: "SOHC", raw_value: "SOHC"),
      a_hash_including(type: "year_range_candidate", value: "89/03", raw_value: "89/03")
    )
    expect(facts).to all(include(confidence: "candidate"))
  end

  it "preserves multiple candidates without linking them together or expanding ambiguous years" do
    facts = described_class.new.call("L4 L6 KA24DE L20B DOHC SOHC 8V 12V 76/14")

    expect(facts.select { |fact| fact[:type] == "engine_code_candidate" }.map { |fact| fact[:value] }).to eq([ "KA24DE", "L20B" ])
    expect(facts.select { |fact| fact[:type] == "cylinder_count_candidate" }.map { |fact| fact[:value] }).to eq([ 4, 6 ])
    expect(facts.select { |fact| fact[:type] == "valve_count_candidate" }.map { |fact| fact[:value] }).to eq([ 8, 12 ])
    expect(facts.find { |fact| fact[:type] == "year_range_candidate" }[:value]).to eq("76/14")
  end

  it "does not treat supplier part references or unrelated numbers as verified engine codes" do
    facts = described_class.new.call("QJC20G FS-001225 JC20 197 DIENTES")
    expect(facts.map { |fact| fact[:type] }).not_to include("engine_code_candidate", "year_range_candidate")
  end

  it "handles case and whitespace variations while preserving original evidence" do
    facts = described_class.new.call("nissan  4   cil ka24e sohc 12 val 89/03")
    expect(facts).to include(a_hash_including(type: "engine_code_candidate", value: "KA24E", raw_value: "ka24e"))
    expect(facts).to include(a_hash_including(type: "cylinder_count_candidate", value: 4))
  end

  it "extracts multiple displacement candidates without confusing ring dimensions" do
    facts = described_class.new.call("L4 L6 1.8 2.4 2.0 KA24DE DOHC RAN 1.2 1.2 2.5")
    values = facts.select { |fact| fact[:type] == "displacement_liters_candidate" }.map { |fact| fact[:value] }
    expect(values).to eq([ 1.8, 2.4, 2.0 ])
    expect(described_class.new.call("ANILLOS 89X1.2X1.2X2").map { |fact| fact[:type] }).not_to include("displacement_liters_candidate")
  end

  it "interprets two- and four-digit ranges with slash or dash using the cutoff-30 policy" do
    inputs = {
      "99/04" => [ 1999, 2004 ], "1999/04" => [ 1999, 2004 ], "99/2004" => [ 1999, 2004 ], "1999/2004" => [ 1999, 2004 ],
      "99-04" => [ 1999, 2004 ], "1999–04" => [ 1999, 2004 ], "99—2004" => [ 1999, 2004 ], "1999 - 2004" => [ 1999, 2004 ],
      "00/30" => [ 2000, 2030 ], "31/99" => [ 1931, 1999 ]
    }

    inputs.each do |text, expected_years|
      fact = described_class.call("SENTRA #{text}").find { |candidate| candidate[:type] == "year_range_candidate" }
      expect(fact).to include(raw_value: text, start_year: expected_years.first, end_year: expected_years.last,
        century_policy: "two_centuries_cutoff_30_v1", interpretation_status: "interpreted")
    end
  end

  it "extracts make and model as candidates while retaining ambiguous range evidence" do
    facts = described_class.call("NISSAN SENTRA 31/30 QR20DE")
    vehicle = facts.find { |candidate| candidate[:type] == "vehicle_candidate" }
    range = facts.find { |candidate| candidate[:type] == "year_range_candidate" }

    expect(vehicle[:value]).to include("make" => "Nissan", "model" => "SENTRA", "year_start" => 1931, "year_end" => 2030)
    expect(range).to include(interpretation_status: "unresolved", unresolved_reason: "implausibly_wide_year_range", raw_value: "31/30")
    expect(vehicle[:confidence]).to eq("candidate")
  end

  it "does not parse year-like substrings embedded in part identifiers" do
    expect(described_class.call("PART99/04X").map { |fact| fact[:type] }).not_to include("year_range_candidate")
  end

  it "keeps separate make, model and year candidates distinct in multi-vehicle descriptions" do
    vehicles = described_class.call("NISSAN SENTRA 99/04 TOYOTA COROLLA 2005-08")
      .select { |fact| fact[:type] == "vehicle_candidate" }

    expect(vehicles.map { |fact| fact[:value] }).to eq([
      { "make" => "Nissan", "model" => "SENTRA", "year_start" => 1999, "year_end" => 2004, "year_range_status" => "interpreted" },
      { "make" => "Toyota", "model" => "COROLLA", "year_start" => 2005, "year_end" => 2008, "year_range_status" => "interpreted" }
    ])
  end

  it "ends the model before compact cylinder markers and engine descriptions" do
    nissan = described_class.call("NISSAN PICK UP 4CIL 1989/2003").find { |fact| fact[:type] == "vehicle_candidate" }
    expect(nissan[:value]).to include("make" => "Nissan", "model" => "PICK UP", "year_start" => 1989, "year_end" => 2003)

    chevrolet = described_class.call("CHEVROLET V8 VORTEC LS1 1999/2023")
    expect(chevrolet.map { |fact| fact[:type] }).not_to include("vehicle_candidate")
    expect(chevrolet).to include(
      a_hash_including(type: "cylinder_count_candidate", value: 8, raw_value: "V8"),
      a_hash_including(type: "engine_family_candidate", value: "VORTEC"),
      a_hash_including(type: "engine_code_candidate", value: "LS1")
    )
    expect(described_class.call("NISSAN PICK UP 4CIL")).to include(a_hash_including(type: "cylinder_count_candidate", value: 4, raw_value: "4CIL"))
  end

  it "keeps a vehicle name that precedes engine specifications" do
    vehicle = described_class.call("CHEVROLET SILVERADO V8 VORTEC LS1 1999/2023").find { |fact| fact[:type] == "vehicle_candidate" }
    expect(vehicle[:value]["model"]).to eq("SILVERADO")
  end
end
