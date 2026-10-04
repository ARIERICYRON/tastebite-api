# Rational arithmetic avoids floating-point errors at package boundaries.
# Cups/spoons use Canadian metric measures: cup 250 mL, tbsp 15 mL, tsp 5 mL.
class GroceryQuantity
  FRACTIONS = { "¼" => "1/4", "½" => "1/2", "¾" => "3/4", "⅓" => "1/3", "⅔" => "2/3", "⅛" => "1/8", "⅜" => "3/8", "⅝" => "5/8", "⅞" => "7/8" }.freeze
  UNIT_GROUPS = [
    [%w[g gram grams], "g", "1"], [%w[kg kilogram kilograms], "g", "1000"], [%w[mg milligram milligrams], "g", "0.001"],
    [%w[oz ounce ounces], "g", "28.349523125"], [%w[lb lbs pound pounds], "g", "453.59237"],
    [%w[ml milliliter milliliters millilitre millilitres], "ml", "1"], [%w[l liter liters litre litres], "ml", "1000"],
    [%w[cup cups], "ml", "250"], [%w[tbsp tablespoon tablespoons], "ml", "15"], [%w[tsp teaspoon teaspoons], "ml", "5"],
    [["", "each", "piece", "pieces", "pc", "pcs", "item", "items"], "each", "1"],
    [%w[clove cloves], "clove", "1"]
  ].freeze
  UNITS = UNIT_GROUPS.each_with_object({}) { |(aliases, dimension, factor), table| aliases.each { |name| table[name] = [dimension, factor.to_r] } }.freeze

  def self.key(name)
    name.to_s.strip.downcase.gsub(/\s+/, " ")
  end

  def self.parse(value)
    text = value.to_s.strip
    return nil if text.length > 200
    FRACTIONS.each { |symbol, fraction| text = text.gsub(symbol, " #{fraction}") }
    text = text.strip.gsub(/\s+/, " ")
    if text.match?(/\A(?:\d+(?:\.\d+)?|\.\d+)\z/)
      text.to_r
    elsif (match = text.match(/\A(?:(\d+) )?(\d+)\/(\d+)\z/)) && match[3].to_i.positive?
      match[1].to_i + Rational(match[2].to_i, match[3].to_i)
    end
  end

  def self.unit(value)
    UNITS[value.to_s.strip.downcase.delete_suffix(".")]
  end

  def self.display(value)
    return "<0.0001" if value.positive? && value < Rational(1, 10_000)
    number = (BigDecimal(value.numerator.to_s) / value.denominator).round(4).to_s("F")
    number.sub(/\.?0+\z/, "")
  end
end
