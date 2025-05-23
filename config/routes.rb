Rails.application.routes.draw do
  root 'main#index' # Health check route
  post '/validate', to: 'main#validate'
  get '/download/:filename', to: 'main#download'
end

