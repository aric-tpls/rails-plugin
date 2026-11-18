# Rails application template for rails plugin new (mountable engine).
# Applied inside the generator container with /output as the plugin root.
# NOTE: cwd during apply is the dummy app (test/dummy), and relative Thor
# actions resolve against the plugin root only when it equals cwd. So all
# logic derives paths from the DESTINATION_ROOT env var the justfile exports.

plugin_root = ENV["PLUGIN_ROOT"] || Dir.pwd
plugin_name = File.basename(plugin_root)                 # e.g. my_widgets
module_name = plugin_name.split("_").map(&:capitalize).join # e.g. MyWidgets

scaffold = "/template/scaffold"

def in_root(path) = File.join(ENV["PLUGIN_ROOT"] || Dir.pwd, path)

# 1. Static files
copy_file "#{scaffold}/Dockerfile", in_root("Dockerfile")
copy_file "#{scaffold}/docker-compose.dev.yml", in_root("docker-compose.dev.yml")
copy_file "#{scaffold}/justfile", in_root("justfile")
copy_file "#{scaffold}/bin/ci", in_root("bin/ci")
chmod in_root("bin/ci"), 0o755
copy_file "#{scaffold}/.ruby-version", in_root(".ruby-version")

# Append ignore rules to the generated .gitignore
append_to_file in_root(".gitignore") do
  File.read("#{scaffold}/.gitignore")
end

# README with the real plugin name substituted
readme = File.read("#{scaffold}/README.md")
  .gsub("<PLUGIN_NAME>", plugin_name)
  .gsub("<name>", plugin_name)
create_file in_root("README.md"), readme

# 2. Gemfile: dummy app needs sqlite3; plugin generator already adds a loose
#    "gem 'sqlite3'" entry, so tighten it to >= 2.1 instead of adding a duplicate.
gemfile = File.read(in_root("Gemfile"))
  .gsub(/^gem ["']sqlite3["'].*$/, 'gem "sqlite3", ">= 2.1"')
create_file in_root("Gemfile"), gemfile
Dir.chdir(plugin_root) { run "bundle lock" }

# 3. Example helper + test
create_file in_root("app/helpers/#{plugin_name}/example_helper.rb"), <<~RUBY
  module #{module_name}
    module ExampleHelper
      def example_greeting(name = "world")
        "Hello, \#{name}!"
      end
    end
  end
RUBY

create_file in_root("test/example_helper_test.rb"), <<~RUBY
  require "test_helper"

  module #{module_name}
    class ExampleHelperTest < ActiveSupport::TestCase
      include #{module_name}::ExampleHelper

      test "greets by name" do
        assert_equal "Hello, Alice!", example_greeting("Alice")
        assert_equal "Hello, world!", example_greeting
      end
    end
  end
RUBY

# 4. docs placeholders
create_file in_root("docs/superpowers/specs/.keep"), ""
create_file in_root("docs/superpowers/plans/.keep"), ""

# 5. Health endpoint: mountable engine dummy apps don't get the default
#    /up route, so add it for `just up` verification.
append_to_file in_root("test/dummy/config/routes.rb") do
  <<~RUBY

    Rails.application.routes.draw do
      # Reveal health status on /up (200 if the app boots, otherwise 500).
      get "up" => "rails/health#show", as: :rails_health_check
    end
  RUBY
end
