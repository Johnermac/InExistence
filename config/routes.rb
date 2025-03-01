Rails.application.routes.draw do
  root 'main#health_check' # Health check route
  post '/validate', to: 'main#validate'
  get '/download/:filename', to: 'main#download'
end
