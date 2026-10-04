Rails.application.routes.draw do
  # Browser tests must prove the running server uses their isolated database.
  if Rails.env.test?
    get "/__test__/database", to: ->(_env) {
      [200, { "Content-Type" => "application/json" }, [{ database: ActiveRecord::Base.connection_db_config.database }.to_json]]
    }
  end
  namespace :api do
    namespace :v1 do
      post "auth/signup", to: "auth#signup"
      post "auth/login", to: "auth#login"
      post "auth/forgot-password", to: "auth#forgot_password"
      post "auth/reset-password", to: "auth#reset_password"
      get "me", to: "auth#me"
      patch "me/account", to: "auth#update_account"
      get "me/saved", to: "bookmarks#index"

      get "search", to: "discovery#search"
      get "explore/trending", to: "discovery#trending"

      get "notifications", to: "notifications#index"
      post "notifications/read", to: "notifications#read"

      get "meal-plans", to: "meal_plans#show"
      post "meal-plans/entries", to: "meal_plans#add_entry"
      delete "meal-plans/entries/:id", to: "meal_plans#remove_entry"
      get "meal-plans/shopping-list", to: "meal_plans#shopping_list"

      post "recipes/:id/save", to: "bookmarks#create"
      delete "recipes/:id/save", to: "bookmarks#destroy"
      resources :recipes do
        resources :reviews, only: [:index, :create, :destroy], module: :recipes
      end

      resources :posts, only: [:index, :show, :create, :destroy] do
        member do
          post "like", to: "likes#create"
          delete "like", to: "likes#destroy"
        end
        resources :comments, only: [:index, :create], module: :posts
      end

      get "users/:handle", to: "users#show"
      post "users/:handle/follow", to: "follows#create"
      delete "users/:handle/follow", to: "follows#destroy"
      get "users/:handle/followers", to: "follows#followers"
      get "users/:handle/following", to: "follows#following"
    end
  end
end
