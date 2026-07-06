Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      post "auth/signup", to: "auth#signup"
      post "auth/login", to: "auth#login"
      get "me", to: "auth#me"
      get "me/saved", to: "bookmarks#index"

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
