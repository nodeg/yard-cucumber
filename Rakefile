# frozen_string_literal: true

require 'rake'
require 'fileutils'
require 'yard'
require 'yard/rake/yardoc_task'
require 'rubygems/package_task'

# 1. FIX: Add 'lib' to the LOAD_PATH so we can load the code manually
$LOAD_PATH.unshift(File.expand_path('lib', __dir__))

# 2. FIX: Disable automatic plugin loading to stop the "Error loading plugin" message.
# We will load our plugin manually via the '-e' flag instead.
YARD::Config.options[:load_plugins] = false

task default: :gendoc

desc 'Clean out any existing documentation'
task :clean do
  puts 'Removing documentation...'
  FileUtils.rm_rf(['doc', '.yardoc'])
end

desc 'Generate documentation from the example data'
YARD::Rake::YardocTask.new(:gendoc) do |t|
  Rake::Task['clean'].invoke
  t.files   = ['example/**/*']
  # Removed invalid '--noplugins' flag
  t.options = ['--debug', '-e', './lib/yard-cucumber.rb']
end

desc 'Run the YARD Server'
task server: :gendoc do
  require 'yard/cli/server'

  puts "Starting YARD Server..."
  # 3. FIX: Run the server in-process using the Ruby API.
  # This preserves our configuration (plugins = false) and LOAD_PATH.
  YARD::CLI::Server.run('-e', './lib/yard-cucumber.rb')
end

# -------------------------------------------------------------------------
# GEM PACKAGING
# -------------------------------------------------------------------------
spec = Gem::Specification.load('yard-cucumber.gemspec')

if spec
  Gem::PackageTask.new(spec) do |pkg|
    pkg.need_tar = false
    pkg.need_zip = false
  end
else
  desc 'Create the yard-cucumber gem (Manual Fallback)'
  task :gem do
    sh 'gem build yard-cucumber.gemspec'
  end
end
