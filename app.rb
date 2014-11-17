require 'sinatra'
require 'capybara/poltergeist'
require 'csv'
require 'json'
require 'rest_client'

configure do
  set :views, 'app/views'
end
configure :production do
  require 'newrelic_rpm'
end

Dir[File.join(File.dirname(__FILE__), 'app', '**', '*.rb')].each do |file|
  require file
end

get '/' do
  erb :index
end

post '/create' do
  username = params['username']
  password = params['password']
  filename = params['my_file'][:tempfile]
  Bot.new(username, password, filename).populate_wordpress_and_pipedeals
  File.delete(filename.path)
  redirect '/'
end
