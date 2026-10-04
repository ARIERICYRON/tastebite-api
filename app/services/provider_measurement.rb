# Accept only a complete numeric amount followed by a known unit, or a bare count.
# Ranges, alternatives, package descriptions and preparation words are never guessed.
class ProviderMeasurement
  def self.parse(raw)
    original = raw.to_s
    text = original.strip
    amount_pattern = '(?:\d+\s+\d+/\d+|\d+/\d+|\d+(?:\.\d+)?|\.\d+|\d*\s*[¼½¾⅓⅔⅛⅜⅝⅞])'
    match = text.match(/\A(#{amount_pattern})(?:\s+([a-zA-Z.]+))?\z/)
    if match && %w[cup cups].include?(match[2]&.downcase)
      return { quantity: nil, unit: nil, original_measurement: original, quantity_issue: "Provider cup volume is unconfirmed" }
    end
    if match && GroceryQuantity.parse(match[1]) && GroceryQuantity.unit(match[2])
      { quantity: match[1], unit: match[2], original_measurement: original, quantity_issue: nil }
    else
      { quantity: nil, unit: nil, original_measurement: original, quantity_issue: "Ambiguous or unsupported provider measurement" }
    end
  end
end
