# Rails application template for rails plugin new (mountable engine).
# Applied inside the generator container with /output as the plugin root.

plugin_name = File.basename(Dir.pwd)                     # e.g. my_widgets
module_name = plugin_name.split("_").map(&:capitalize).join # e.g. MyWidgets

scaffold = "/template/scaffold"

# 1. Static files
copy_file "#{scaffold}/Dockerfile", "Dockerfile"
copy_file "#{scaffold}/docker-compose.dev.yml", "docker-compose.dev.yml"
copy_file "#{scaffold}/justfile", "justfile"
copy_file "#{scaffold}/bin/ci", "bin/ci"
chmod "bin/ci", 0o755
copy_file "#{scaffold}/.ruby-version", ".ruby-version"

# Append ignore rules to the generated .gitignore
append_to_file ".gitignore" do
  File.read("#{scaffold}/.gitignore")
end

# README with the real plugin name substituted
readme = File.read("#{scaffold}/README.md")
  .gsub("<PLUGIN_NAME>", plugin_name)
  .gsub("<name>", plugin_name)
create_file "README.md", readme

# 2. Gemfile: dummy app needs sqlite3; lock without installing
gem "sqlite3", ">= 2.1"
run "bundle lock"

# 3. Example helper + test
create_file "app/helpers/#{plugin_name}/example_helper.rb", <<~RUBY
  module #{module_name}
    module ExampleHelper
      def example_greeting(name = "world")
        "Hello, #{name}!"
      end
    end
  end
RUBY

create_file "test/example_helper_test.rb", <<~RUBY
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
create_file "docs/superpowers/specs/.keep", ""
create_file "docs/superpowers/plans/.keep", ""
