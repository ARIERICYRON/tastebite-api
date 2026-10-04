require "rails_helper"
RSpec.describe ProviderMeasurement do
  it "accepts complete known amounts and preserves the exact original measurement" do
    { "1 pound" => ["1", "pound"], "1 1/2 kg" => ["1 1/2", "kg"], "½ tsp" => ["½", "tsp"], "3 cloves " => ["3", "cloves"], "2" => ["2", nil] }.each do |raw, parsed|
      expect(described_class.parse(raw)).to include(quantity: parsed[0], unit: parsed[1], original_measurement: raw, quantity_issue: nil)
    end
  end
  it "flags cups because the provider does not identify their volume standard" do
    expect(described_class.parse("1/4 cup")).to include(quantity: nil, original_measurement: "1/4 cup", quantity_issue: "Provider cup volume is unconfirmed")
  end
  it "never guesses ranges, packs, descriptive counts, missing amounts or alternative units" do
    ["", "to taste", "1 tin ", "6 leaves", "sprinkling", "1-2 cups", "2 x 400g", "1/0 g", "-1 g", "100 g chopped", "1 cup or 250ml"].each do |raw|
      expect(described_class.parse(raw)).to include(quantity: nil, unit: nil, original_measurement: raw, quantity_issue: "Ambiguous or unsupported provider measurement")
    end
  end
end
