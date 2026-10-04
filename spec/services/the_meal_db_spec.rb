require "rails_helper"
RSpec.describe TheMealDb do
  let(:client) { described_class.new }
  let(:meal) { JSON.parse(File.read(Rails.root.join("spec/fixtures/meal_db/meal.json")))["meals"].first }
  it "intersects supported single filters and search without full-detail fanout" do
    other = meal.merge("idMeal" => "999", "strMeal" => "Other")
    expect(client).to receive(:request).with("search.php", { s: "Penne" }).and_return("meals" => [meal, other])
    expect(client).to receive(:request).with("filter.php", { "c" => "Vegetarian" }).and_return("meals" => [meal])
    expect(client).to receive(:request).with("filter.php", { "a" => "Italian" }).and_return("meals" => [meal])
    expect(client).to receive(:request).with("filter.php", { "i" => "garlic" }).and_return("meals" => [meal])
    expect(client.search(q: "Penne", category: "Vegetarian", cuisine: "Italian", ingredient: "garlic").map { |row| row[:provider_id] }).to eq(["52771"])
  end
  it "preserves full ingredients and instructions without invented metadata" do
    allow(client).to receive(:request).and_return("meals" => [meal])
    result = client.detail("52771")
    expect(result).to include(servings: nil, time_minutes: nil, nutrition: nil, instructions: meal["strInstructions"])
    expect(result[:ingredients][3]).to include(original_measurement: "1 tin ", quantity: nil)
    expect(result[:provider_url]).to eq("https://www.themealdb.com/meal/52771")
  end
  it "handles empty results, unavailable details, unsupported queries and malformed payloads" do
    allow(client).to receive(:request).and_return("meals" => nil)
    expect(client.search).to eq([])
    expect { client.detail("52771") }.to raise_error(TheMealDb::NotFound)
    expect { client.detail("../secrets") }.to raise_error(TheMealDb::InvalidQuery)
    expect { client.search(ingredient: "garlic,salt") }.to raise_error(TheMealDb::InvalidQuery)
    expect { client.search(q: "x" * 101) }.to raise_error(TheMealDb::InvalidQuery)
    allow(client).to receive(:request).and_return("meals" => ["wrong"])
    expect { client.search }.to raise_error(TheMealDb::Unavailable)
  end
  it "bounds HTTP timeouts and turns timeout responses into safe errors" do
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:new).and_return(http)
    expect(http).to receive(:use_ssl=).with(true)
    expect(http).to receive(:open_timeout=).with(3)
    expect(http).to receive(:read_timeout=).with(5)
    expect(http).to receive(:write_timeout=).with(5)
    allow(http).to receive(:request).and_raise(Net::ReadTimeout)
    expect { client.search(q: "timeout") }.to raise_error(TheMealDb::Unavailable, /temporarily unavailable/)
  end
  it "rejects malformed JSON, oversized responses and non-success statuses" do
    http = double("http")
    %i[use_ssl= open_timeout= read_timeout= write_timeout=].each { |setter| allow(http).to receive(setter) }
    allow(Net::HTTP).to receive(:new).and_return(http)
    response = Net::HTTPOK.new("1.1", "200", "OK")
    allow(http).to receive(:request).and_yield(response)
    ["not JSON", "{}", "x" * 2_000_001].each do |body|
      allow(response).to receive(:read_body).and_yield(body)
      expect { client.search(q: "invalid") }.to raise_error(TheMealDb::Unavailable)
    end
    allow(http).to receive(:request).and_yield(Net::HTTPServiceUnavailable.new("1.1", "503", "Unavailable"))
    expect { client.search(q: "failure") }.to raise_error(TheMealDb::Unavailable)
  end
  it "rejects unsafe source/image URLs and never exposes an API key in a source URL" do
    expect(TheMealDb.safe_url("javascript:alert(1)")).to be_nil
    expect(TheMealDb.safe_url("https://name:password@example.com/")).to be_nil
    expect(TheMealDb.safe_url("https://evil.example/image.png", image: true)).to be_nil
  end
  it "requires commercial-access confirmation and a production key in production" do
    allow(Rails.env).to receive(:production?).and_return(true)
    prior_key, prior_confirm = ENV["THEMEALDB_API_KEY"], ENV["THEMEALDB_COMMERCIAL_ACCESS_CONFIRMED"]
    ENV["THEMEALDB_API_KEY"] = "1"
    ENV.delete("THEMEALDB_COMMERCIAL_ACCESS_CONFIRMED")
    expect { described_class.new }.to raise_error(TheMealDb::Unavailable, /production access/)
    ENV["THEMEALDB_API_KEY"] = "test-production"
    ENV["THEMEALDB_COMMERCIAL_ACCESS_CONFIRMED"] = "true"
    expect { described_class.new }.not_to raise_error
  ensure
    ENV["THEMEALDB_API_KEY"], ENV["THEMEALDB_COMMERCIAL_ACCESS_CONFIRMED"] = prior_key, prior_confirm
  end
end
