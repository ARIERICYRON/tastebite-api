require "net/http"
require "json"

class TheMealDb
  class Unavailable < StandardError; end
  class NotFound < StandardError; end
  class InvalidQuery < StandardError; end
  LIMIT = 100

  def initialize
    @key = ENV.fetch("THEMEALDB_API_KEY", Rails.env.production? ? "" : "1")
    if Rails.env.production? && (ENV["THEMEALDB_COMMERCIAL_ACCESS_CONFIRMED"] != "true" || @key.blank? || @key == "1")
      raise Unavailable, "TheMealDB production access is not configured."
    end
    raise Unavailable, "TheMealDB key is not configured." unless @key.match?(/\A[a-zA-Z0-9_-]+\z/)
  end

  def catalogs
    Rails.cache.fetch("mealdb:catalogs:v1:#{@key}", expires_in: 24.hours) do
      { categories: list("c", "strCategory"), cuisines: list("a", "strArea"), ingredients: list("i", "strIngredient") }
    end
  end

  def search(q: nil, category: nil, cuisine: nil, ingredient: nil)
    values = { q: q, category: category, cuisine: cuisine, ingredient: ingredient }.transform_values { |value| value.to_s.strip }
    raise InvalidQuery, "Search and filter values must be at most 100 characters." if values.values.any? { |v| v.length > 100 }
    raise InvalidQuery, "Select one ingredient." if values[:ingredient].include?(",")
    sets = []
    sets << meals("search.php", s: values[:q]) if values[:q].present?
    { category: "c", cuisine: "a", ingredient: "i" }.each do |name, parameter|
      sets << meals("filter.php", parameter => values[name]) if values[name].present?
    end
    sets << meals("search.php", f: "a") if sets.empty?
    ids = sets.map { |rows| rows.map { |meal| meal["idMeal"] } }.reduce { |a, b| a & b }
    sets.first.select { |meal| ids.include?(meal["idMeal"]) }.first(LIMIT).map { |meal| summary(meal) }
  end

  def detail(id)
    raise InvalidQuery, "Invalid provider recipe ID." unless id.to_s.match?(/\A\d{1,12}\z/)
    meal = meals("lookup.php", i: id).find { |row| row["idMeal"] == id.to_s }
    raise NotFound, "TheMealDB recipe is unavailable." unless meal
    full(meal)
  end

  def self.safe_url(value, image: false)
    uri = URI.parse(value.to_s)
    return nil unless %w[http https].include?(uri.scheme) && uri.host.present? && !uri.userinfo
    return nil if image && !%w[www.themealdb.com themealdb.com].include?(uri.host.downcase)
    uri.to_s
  rescue URI::InvalidURIError
    nil
  end

  private

  def request(endpoint, params)
    key = @key
    uri = URI("https://www.themealdb.com/api/json/v1/#{key}/#{endpoint}")
    uri.query = URI.encode_www_form(params)
    Rails.cache.fetch(["mealdb", key, endpoint, params].join(":"), expires_in: endpoint == "lookup.php" ? 1.hour : 5.minutes) do
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 3
      http.read_timeout = 5
      http.write_timeout = 5
      body = +""
      http.request(Net::HTTP::Get.new(uri)) do |response|
        raise Unavailable, "TheMealDB is temporarily unavailable." unless response.is_a?(Net::HTTPSuccess)
        response.read_body do |chunk|
          body << chunk
          raise Unavailable, "Invalid TheMealDB response." if body.bytesize > 2_000_000
        end
      end
      data = JSON.parse(body)
      raise Unavailable, "Invalid TheMealDB response." unless data.is_a?(Hash) && data.key?("meals") && (data["meals"].nil? || data["meals"].is_a?(Array))
      data
    end
  rescue Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, JSON::ParserError, Timeout::Error, SocketError, IOError, SystemCallError, OpenSSL::SSL::SSLError
    raise Unavailable, "TheMealDB is temporarily unavailable. Please retry."
  end

  def meals(endpoint, params)
    rows = request(endpoint, params)["meals"] || []
    raise Unavailable, "Invalid TheMealDB response." unless rows.all? { |row| row.is_a?(Hash) && row["idMeal"].to_s.match?(/\A\d{1,12}\z/) && row["strMeal"].is_a?(String) && row["strMeal"].present? }
    rows.first(LIMIT)
  end

  def list(parameter, field)
    data = request("list.php", parameter => "list")["meals"] || []
    raise Unavailable, "Invalid TheMealDB catalog." unless data.all? { |row| row.is_a?(Hash) && row[field].is_a?(String) }
    data.map { |row| row[field] }.reject(&:blank?).uniq.sort
  end

  def summary(meal)
    { provider: "themealdb", provider_id: meal["idMeal"], title: meal["strMeal"], cover_image_url: self.class.safe_url(meal["strMealThumb"], image: true), category: meal["strCategory"], cuisine: meal["strArea"], provider_url: "https://www.themealdb.com/meal/#{meal['idMeal']}" }
  end

  def full(meal)
    summary(meal).merge(
      source_url: self.class.safe_url(meal["strSource"]), video_url: self.class.safe_url(meal["strYoutube"]),
      instructions: meal["strInstructions"].to_s, creative_commons: meal["strCreativeCommons"], servings: nil, time_minutes: nil, nutrition: nil,
      ingredients: (1..20).filter_map do |index|
        name = meal["strIngredient#{index}"].to_s.strip
        next if name.blank?
        ProviderMeasurement.parse(meal["strMeasure#{index}"]).merge(name: name, position: index)
      end
    )
  end
end
