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
      post 'boot'
      post 'boot_cloud'
      post 'boot_subnet'
      post 'boot_instance'
      post 'unboot'
      post 'unboot_cloud'
      post 'unboot_subnet'
      post 'unboot_instance'

      post 'destroy_scenario'
      post 'destroy_cloud'
      post 'destroy_subnet'
      post 'destroy_instance'

      post 'add_cloud'
      post 'add_subnet'
      post 'add_instance'

      post 'modify_cloud'
      post 'modify_subnet'
      post 'modify_instance'

      post 'delete_cloud'
      post 'delete_subnet'
      post 'delete_instance'

      post 'modify'
      post 'modify_cloud'
      post 'modify_subnet'
      post 'modify_instance'

      post 'add_player'
      post 'modify_players'
      post 'delete_player'

      post 'add_student_group'
      post 'remove_student_group'

      post 'getlog'
      post 'boot_status'

      post 'save_changes'

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
  get 'student_groups/add_to'
  # get 'student_groups/remove_from'
  # post 'student_groups/add_to'

  get 'student', to: 'student#index'

  get 'admin', to: 'admin#index'
  post 'admin/instructor_add'
  post 'admin/instructor_remove'

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
