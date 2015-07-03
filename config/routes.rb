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
      post 'destroyme'

      post 'boot'
      post 'boot_cloud'
      post 'boot_subnet'
      post 'boot_instance'
      post 'unboot'
      post 'unboot_cloud'
      post 'unboot_subnet'
      post 'unboot_instance'
      post 'boot_status'

      post 'destroy_scenario'
      post 'destroy_cloud'
      post 'destroy_subnet'
      post 'destroy_instance'

      post 'modify'
      post 'log_get'
      post 'status'
      post 'clone'

      post 'cloud_modify'
      post 'cloud_add'
      post 'cloud_delete'

      post 'subnet_modify'
      post 'subnet_add'
      post 'subnet_delete'

      post 'instance_modify'
      post 'instance_add'
      post 'instance_delete'
      post 'instance_bash_history'

      post 'player_modify'
      post 'player_add'
      post 'player_delete'
      post 'player_student_group_add'
      post 'player_student_group_remove'

      post 'recipe_view'
      post 'recipe_update_view'
      post 'recipe_global_get'
      post 'recipe_global_add'
      post 'recipe_custom_add'
      post 'recipe_remove'
      post 'recipe_update'

    end
  end
  
  get 'scenarios/destroy/:id', to: 'scenarios#destroy'

  get 'instructor', to: 'instructor#index'

  post 'instructor/student_group_new'
  post 'instructor/student_group_assign'
  post 'instructor/student_group_delete'
  post 'instructor/student_group_remove'

  # get 'student_groups', to: 'student_groups#index'
  # post 'student_groups/new'
  # get 'student_groups/destroy'
  post 'student_groups/add_to'
  # get 'student_groups/remove_from'
  # post 'student_groups/add_to'

  get 'student', to: 'student#index'

  get 'admin', to: 'admin#index'
  post 'admin/instructor_delete'
  post 'admin/instructor_create'
  post 'admin/student_to_instructor'

  # Insecure, needs to be rewritten
  # get 'scoring/instructor/:scenario', to: 'scoring#instructor'
  # get 'scoring/student/:scenario', to: 'scoring#student'
  # post 'scoring/answer_question/:scenario/:question', to: 'scoring#answer_question'
  # get 'scoring/instructor_student/:scenario/:user', to: 'scoring#instructor_student'
  # post 'scoring/answer_open_question'
  # get 'scoring/answer_dump'
  # get 'documentation', to: 'documentation#index'
  # get 'documentation/scenarios/:id', to: 'documentation#show'

  root :to => "home#index"
  devise_for :users, :controllers => {:registrations => "registrations"}
  resources :users
end
