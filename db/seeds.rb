require "securerandom"

if Rails.env.development? || Rails.env.test?
  ActiveRecord::Base.transaction do
    connection = ActiveRecord::Base.connection
    application_tables = connection.tables - %w[schema_migrations ar_internal_metadata]
    populated = application_tables.any? do |table|
      connection.select_value("SELECT 1 FROM #{connection.quote_table_name(table)} LIMIT 1").present?
    end
    if populated
      raise "Refusing to seed a populated database. Existing data was left unchanged."
    end

    puts "Creating cooks..."
    cooks = [
      { name: "Mara Okafor",   handle: "mara",   email: "mara@tastebite.app",   bio: "Weeknight dinners & big-batch cooking." },
      { name: "Diego Alvarez", handle: "diego",  email: "diego@tastebite.app",  bio: "Mexican home cooking, no shortcuts." },
      { name: "Priya Nair",    handle: "priya",  email: "priya@tastebite.app",  bio: "Vegetarian South Indian, mostly." },
      { name: "Sam Lee",       handle: "sam",    email: "sam@tastebite.app",    bio: "Learning to cook, one recipe at a time." },
      { name: "Nina Kraft",    handle: "nina",   email: "nina@tastebite.app",   bio: "Baker. Bread is my love language." },
    ]
    users = cooks.map { |c| User.create!(c.merge(password: SecureRandom.hex(32))) }
    mara, diego, priya, sam, nina = users
    
    puts "Creating recipes..."
    recipes_data = [
      { user: mara, title: "Miso Butter Ramen", difficulty: "Medium", time_minutes: 35, servings: 2, calories: 620,
        description: "A rich, savory ramen with a miso-butter broth that comes together on a weeknight.",
        ingredients: [["Ramen noodles","2","portions"],["White miso","2","tbsp"],["Butter","1","tbsp"],["Garlic","2","cloves"],["Soft-boiled egg","2",""]],
        steps: ["Bring broth to a simmer and whisk in the miso.","Saute garlic in butter until fragrant.","Cook noodles, then combine with broth.","Top with a soft-boiled egg and serve."] },
      { user: priya, title: "Rainbow Harvest Salad", difficulty: "Easy", time_minutes: 20, servings: 2, calories: 480,
        description: "Crisp greens, roasted squash, chickpeas, and a tahini-lemon dressing.",
        ingredients: [["Mixed greens","4","cups"],["Butternut squash","2","cups"],["Chickpeas","1","can"],["Tahini","2","tbsp"],["Lemon","1",""]],
        steps: ["Roast the squash until tender.","Whisk tahini, lemon, and water into a dressing.","Toss greens, squash, and chickpeas.","Drizzle with dressing and serve."] },
      { user: diego, title: "Chicken Tinga Tacos", difficulty: "Medium", time_minutes: 45, servings: 4, calories: 540,
        description: "Smoky shredded chicken in a chipotle-tomato sauce, piled into warm tortillas.",
        ingredients: [["Chicken thighs","1.5","lb"],["Chipotle in adobo","2","tbsp"],["Tomatoes","3",""],["White onion","1",""],["Corn tortillas","8",""]],
        steps: ["Simmer and shred the chicken.","Blend tomatoes, onion, and chipotle.","Combine sauce with chicken and reduce.","Serve in warm tortillas with toppings."] },
      { user: nina, title: "No-Knead Country Loaf", difficulty: "Hard", time_minutes: 90, servings: 8, calories: 180,
        description: "A crackly-crusted, open-crumb loaf with almost no hands-on work.",
        ingredients: [["Bread flour","500","g"],["Water","375","g"],["Salt","10","g"],["Instant yeast","1","g"]],
        steps: ["Mix everything into a shaggy dough.","Rest 12-18 hours until bubbly.","Shape and proof 1 hour.","Bake in a hot Dutch oven until deep brown."] },
      { user: mara, title: "Sheet-Pan Gochujang Salmon", difficulty: "Easy", time_minutes: 25, servings: 2, calories: 510,
        description: "Sweet-spicy glazed salmon and broccoli on one pan.",
        ingredients: [["Salmon fillets","2",""],["Gochujang","2","tbsp"],["Honey","1","tbsp"],["Broccoli","1","head"],["Sesame oil","1","tsp"]],
        steps: ["Whisk gochujang, honey, and sesame oil.","Toss broccoli on the pan and roast 10 min.","Add glazed salmon and roast 12 min more.","Finish with sesame seeds."] },
    ]
    
    recipes = recipes_data.map do |data|
      r = data[:user].recipes.create!(
        title: data[:title], description: data[:description], difficulty: data[:difficulty],
        time_minutes: data[:time_minutes], servings: data[:servings], calories: data[:calories],
        status: "published"
      )
      data[:ingredients].each_with_index do |(name, qty, unit), i|
        r.recipe_ingredients.create!(name: name, quantity: qty, unit: unit, position: i + 1)
      end
      data[:steps].each_with_index do |instruction, i|
        r.recipe_steps.create!(instruction: instruction, position: i + 1)
      end
      r
    end
    
    puts "Creating follows..."
    sam.active_follows.create!(followed: mara)
    sam.active_follows.create!(followed: diego)
    sam.active_follows.create!(followed: priya)
    priya.active_follows.create!(followed: mara)
    diego.active_follows.create!(followed: nina)
    
    puts "Creating saves..."
    sam.bookmarks.create!(recipe: recipes[0])
    sam.bookmarks.create!(recipe: recipes[1])
    priya.bookmarks.create!(recipe: recipes[0])
    nina.bookmarks.create!(recipe: recipes[2])
    
    puts "Creating posts & interactions..."
    post = mara.posts.create!(recipe: recipes[0], caption: "Tonight's ramen hit different. Recipe up now!", image_url: "https://images.tastebite.app/ramen.jpg")
    diego.posts.create!(recipe: recipes[2], caption: "Taco Tuesday, tinga edition.", image_url: "https://images.tastebite.app/tinga.jpg")
    sam.likes.create!(post: post)
    priya.likes.create!(post: post)
    sam.comments.create!(post: post, body: "Making this weekend!")
    
    puts "Done! #{User.count} users, #{Recipe.count} recipes, #{Post.count} posts."
  end
else
  puts "Demo seeds skipped outside development and test."
end

