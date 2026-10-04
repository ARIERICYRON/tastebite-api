class WeeklyGroceryEstimate
  def initialize(plan)
    @plan = plan
  end

  def call
    settings = @plan.shopping_items.index_by(&:ingredient_key)
    grouped = {}
    warnings = []
    @plan.meal_plan_entries.includes(recipe: :recipe_ingredients).each do |entry|
      recipe = entry.recipe
      if recipe.status == "draft" && recipe.user_id != @plan.user_id
        warnings << "A planned recipe is unavailable; its ingredients cannot be included."
        next
      end
      baseline = recipe.servings.to_i
      can_scale = !entry.planned_servings || baseline.positive?
      factor = entry.planned_servings && baseline.positive? ? entry.planned_servings.to_r / baseline : 1.to_r
      warnings << "#{recipe.title}: recipe servings are missing; planned servings cannot be calculated." unless can_scale
      recipe.recipe_ingredients.each do |ingredient|
        key = GroceryQuantity.key(ingredient.name)
        next if key.blank?
        item = grouped[key] ||= { key: key, name: ingredient.name, totals: Hash.new(0.to_r), amounts: [], uncalculated: [] }
        original = [ingredient.quantity, ingredient.unit].compact.join(" ").strip
        quantity = GroceryQuantity.parse(ingredient.quantity)
        unit = GroceryQuantity.unit(ingredient.unit)
        if quantity && unit && can_scale
          item[:totals][unit[0]] += quantity * factor * unit[1]
          item[:amounts] << original
        else
          reason = !can_scale ? "Missing recipe servings" : !quantity ? "Unrecognized quantity" : "Unrecognized unit"
          item[:uncalculated] << { amount: original, reason: reason, recipe_id: recipe.id, planned_servings: entry.planned_servings&.to_f }
          item[:amounts] << original
        end
      end
    end
    items = grouped.values.sort_by { |item| item[:key] }.map { |item| calculate_item(item, settings[item[:key]]) }
    purchase_complete = warnings.empty? && items.all? { |item| !item[:purchase_cost].nil? }
    use_complete = warnings.empty? && items.all? { |item| !item[:ingredient_use_cost].nil? }
    subtotal = money(items.sum { |item| item[:purchase_cost].nil? ? 0.to_d : item[:purchase_cost].to_s.to_d })
    use_subtotal = money(items.sum { |item| item[:ingredient_use_cost].nil? ? 0.to_d : item[:ingredient_use_cost].to_s.to_d })
    balance = @plan.weekly_budget && money(@plan.weekly_budget - subtotal)
    status = if @plan.weekly_budget.nil?
               "not_set"
             elsif !purchase_complete
               balance.negative? ? "over_at_least" : "incomplete"
             else
               balance.negative? ? "over" : "within"
             end
    {
      week_start_date: @plan.week_start_date, location: @plan.location, currency: "CAD", price_source: "manual",
      weekly_budget: @plan.weekly_budget&.to_f, item_count: items.size, items: items,
      complete: purchase_complete, estimated_total: purchase_complete ? subtotal.to_f : nil,
      priced_subtotal: subtotal.to_f, ingredient_use_total: use_complete ? use_subtotal.to_f : nil,
      ingredient_use_subtotal: use_subtotal.to_f, budget_status: status,
      budget_remaining: purchase_complete && balance ? balance.to_f : nil,
      minimum_budget_exceeded: balance&.negative? ? (-balance).to_f : nil,
      missing_prices: items.select { |item| !item[:pantry] && item[:missing_price] }.map { |item| item[:name] },
      uncalculated_items: items.select { |item| !item[:pantry] && item[:purchase_cost].nil? }.map { |item| item[:name] },
      warnings: warnings.uniq
    }
  end

  private

  def money(amount)
    amount.to_s.to_d.round(2, BigDecimal::ROUND_HALF_UP)
  end

  def calculate_item(item, setting)
    pantry = setting&.pantry || false
    price = setting&.package_price
    size = setting&.package_size
    package_unit = GroceryQuantity.unit(setting&.package_unit)
    issues = item[:uncalculated].map { |row| row[:reason] }.uniq
    issues << "Missing manual price" if price.nil?
    issues << "Enter a package size and unit" unless size && package_unit
    issues << "Incompatible ingredient and package units" if package_unit && item[:totals].keys.any? { |dimension| dimension != package_unit[0] }
    can_cost = issues.empty? && item[:totals].size == 1
    if can_cost
      needed = item[:totals].values.first
      package_quantity = size.to_r * package_unit[1]
      packages = (needed / package_quantity).ceil
      use_cost = money(price * BigDecimal(needed.numerator.to_s) / needed.denominator / (BigDecimal(package_quantity.numerator.to_s) / package_quantity.denominator))
      purchase_cost = money(price * packages)
    end
    {
      key: item[:key], name: item[:name], amounts: item[:amounts],
      quantities: item[:totals].map { |unit, quantity| { quantity: GroceryQuantity.display(quantity), unit: unit } },
      uncalculated: item[:uncalculated], checked: setting&.checked || false, pantry: pantry,
      package_price: price&.to_f, package_size: size&.to_f, package_unit: setting&.package_unit,
      missing_price: price.nil?, issues: issues, packages_to_buy: pantry ? 0 : packages,
      ingredient_use_cost: use_cost&.to_f, purchase_cost: pantry ? 0.0 : purchase_cost&.to_f
    }
  end
end
