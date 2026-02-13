# frozen_string_literal: true

require_relative 'lib/yard-cucumber/version'

Gem::Specification.new do |spec|
  spec.name          = 'yard-cucumber'
  spec.version       = CucumberInTheYARD::VERSION
  spec.authors       = ['Franklin Webber']
  spec.email         = ['franklin.webber@gmail.com']

  spec.summary       = 'Cucumber Features in YARD'
  spec.description   = <<~DESC
    YARD-Cucumber is a YARD extension that processes Cucumber Features, Scenarios, Steps,
    Step Definitions, Transforms, and Tags and provides a documentation interface.
  DESC

  spec.homepage      = 'http://github.com/burtlo/yard-cucumber'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.2'

  spec.metadata = {
    'homepage_uri'    => spec.homepage,
    'source_code_uri' => spec.homepage,
    'changelog_uri'   => "#{spec.homepage}/blob/master/History.txt"
  }

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git])
    end
  end

  spec.require_paths = ['lib']

  spec.add_dependency 'cucumber', '~> 10.2'
  spec.add_dependency 'yard',     '~> 0.9'

  # If the gem uses redcarpet for rendering markdown inside YARD:
  spec.add_dependency 'redcarpet', '~> 3.6'

  # DEVELOPMENT DEPENDENCIES
  spec.add_development_dependency 'rake', '~> 13.3'
  spec.add_development_dependency 'webrick'
  spec.add_development_dependency 'rackup'
end
