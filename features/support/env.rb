app_file = File.join(File.dirname(__FILE__), *%w[.. .. tracker-reporter.rb])
require app_file
# Force the application name because polyglot breaks the auto-detection logic.
Sinatra::Application.app_file = app_file

begin require 'rspec/expectations'; rescue LoadError; require 'spec/expectations'; end
require 'rack/test'
require 'capybara/cucumber'

Capybara.app = Sinatra::Application