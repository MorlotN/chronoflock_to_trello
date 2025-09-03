Rails.application.routes.draw do
  get '/callbacks/trello', to: 'callbacks#trello_callback'
  post '/callbacks/trello', to: 'callbacks#trello_callback'
end
