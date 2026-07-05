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
    end
  end
end
