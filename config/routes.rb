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

      post 'log_get'
      post 'clone'
      get  'clone_set'
      post 'save'
      post 'save_as'
      post 'obliterate_custom'

      post 'cloud_add'
      post 'cloud_delete'
      post 'cloud_modify'

      post 'subnet_add'
      post 'subnet_delete'
      post 'subnet_modify'

      post 'instance_add'
      post 'instance_bash_history'
      post 'instance_chef_error'
      post 'instance_delete'
      post 'instance_modify'
      post 'instance_role_add'
      post 'instance_role_remove'

      post 'group_add'
      post 'group_modify'
      post 'group_delete'

      post 'group_player_add'
      post 'group_player_delete'
      post 'group_student_group_add'
      post 'group_student_group_remove'

      post 'group_admin_access_add'
      post 'group_admin_access_remove'
      post 'group_user_access_add'
      post 'group_user_access_remove'

      post 'role_add'
      post 'role_delete'
      post 'role_modify'
      post 'role_recipe_add'
      post 'role_recipe_remove'

      post 'recipe_view'
      post 'recipe_update_view'
      post 'recipe_global_get'
      post 'recipe_global_add'
      post 'recipe_custom_add'
      post 'recipe_remove'
      post 'recipe_update'

    end
  end

  post 'scenarios/create_custom'
  post 'scenarios/obliterate_custom'
  get 'scenarios/destroy/:id', to: 'scenarios#destroy'

  get  'admin', to: 'admin#index'
  post 'admin/user_delete'
  post 'admin/instructor_create'
  post 'admin/student_to_instructor'
  post 'admin/instructor_to_student'
  post 'admin/reset_password'
  post 'admin/student_group_create'
  post 'admin/student_group_destroy'
  post 'admin/student_group_user_add'
  post 'admin/student_group_user_remove'

  get 'instructor', to: 'instructor#index'
  post 'instructor/student_group_create'
  post 'instructor/student_group_destroy'
  post 'instructor/student_group_user_add'
  post 'instructor/student_group_user_remove'

  get 'student', to: 'student#index'

  root :to => "home#index"
  devise_for :users, :controllers => {:registrations => "registrations"}
  resources :users
end
