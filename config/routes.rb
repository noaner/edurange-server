Edurange::Application.routes.draw do
  get 'management/clean'
  get 'management/status'

  resources :instance_groups

  resources :players

  resources :groups

  resources :instance_roles

  resources :roles

  resources :instances

  resources :subnets

  resources :clouds

  resources :scenarios do
    member do
      get 'boot'
    end
  end

  root :to => "home#index"
  devise_for :users, :controllers => {:registrations => "registrations"}
  resources :users
end
