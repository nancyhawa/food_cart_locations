require 'bundler/setup'
Bundler.require(:default, :development, :test)

$LOAD_PATH << '.'
Dir["lib/*.rb"].each {|f| require f}
