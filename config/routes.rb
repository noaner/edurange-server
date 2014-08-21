Edurange::Application.routes.draw do
  get 'management/clean'
  get 'management/status'
  get 'management/purge'

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
      get 'status'
      get 'boot'
      get 'dev_boot'
      get 'unboot'
      get 'dev_unboot'
    end
  end

  get 'instructor', to: 'instructor#index'
  get 'instructor/groups'

  get 'student_groups', to: 'student_groups#index'
  post 'student_groups/new'
  get 'student_groups/destroy'
  get 'student_groups/add_to'
  get 'student_groups/remove_from'
  post 'student_groups/add_to'

  get 'student', to: 'student#index'

  get 'admin', to: 'admin#index'
  post 'admin/instructor_add'
  get 'admin/instructor_remove'

  root :to => "home#index"
  devise_for :users, :controllers => {:registrations => "registrations"}
  resources :users
end
