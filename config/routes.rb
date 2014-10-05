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
      get 'test_console'
      get 'boot_toggle'
      post 'modify_players'
    end
  end

  get 'scenarios/destroy/:id', to: 'scenarios#destroy'

  get 'instructor', to: 'instructor#index'
  post 'instructor/student_group_new'
  post 'instructor/student_group_assign'
  get 'instructor/student_group_delete'
  get 'instructor/student_group_remove'

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

  get 'scoring/instructor/:scenario', to: 'scoring#instructor'
  get 'scoring/student/:scenario', to: 'scoring#student'
  post 'scoring/answer_question/:scenario/:question', to: 'scoring#answer_question'
  get 'scoring/instructor_student/:scenario/:user', to: 'scoring#instructor_student'
  post 'scoring/answer_open_question'

  get 'documentation', to: 'documentation#index'
  get 'documentation/scenarios/:id', to: 'documentation#show'

  root :to => "home#index"
  devise_for :users, :controllers => {:registrations => "registrations"}
  resources :users
end
