Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      post "auth/signup", to: "auth#signup"
      post "auth/login", to: "auth#login"
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
      resources :recipes

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
