# frozen_string_literal: true

require 'yard'
require 'gherkin'

require_relative 'yard-cucumber/version'

# ----------------------------------------------------------------------
# Domain Object Model (YARD CodeObjects)
# ----------------------------------------------------------------------
require_relative 'yard/code_objects/cucumber/base'
require_relative 'yard/code_objects/cucumber/namespace_object'
require_relative 'yard/code_objects/cucumber/feature'
require_relative 'yard/code_objects/cucumber/scenario_outline'
require_relative 'yard/code_objects/cucumber/scenario'
require_relative 'yard/code_objects/cucumber/step'
require_relative 'yard/code_objects/cucumber/tag'

require_relative 'yard/code_objects/step_transformer'
require_relative 'yard/code_objects/step_definition'
require_relative 'yard/code_objects/step_transform'

# ----------------------------------------------------------------------
# Parsers & Builders
# ----------------------------------------------------------------------
require_relative 'cucumber/city_builder'
require_relative 'yard/parser/cucumber/feature'

# ----------------------------------------------------------------------
# Handlers (Step Definition Parsing)
# ----------------------------------------------------------------------
# Handlers for Cucumber Feature files
require_relative 'yard/handlers/cucumber/base'
require_relative 'yard/handlers/cucumber/feature_handler'
require_relative 'yard/handlers/step_definition_handler'
require_relative 'yard/handlers/step_transform_handler'
require_relative 'yard/handlers/constant_transform_handler'

require_relative 'yard/templates/helpers/base_helper'

# ----------------------------------------------------------------------
# Server Components
# ----------------------------------------------------------------------
require_relative 'yard/server/adapter'
require_relative 'yard/server/commands/list_command'
require_relative 'yard/server/router'

# ----------------------------------------------------------------------
# Template Registration
# ----------------------------------------------------------------------

# Register the location of the template plugin
YARD::Templates::Engine.register_template_path File.join(__dir__, 'templates')

# Register static paths for the YARD server
YARD::Server.register_static_path File.join(__dir__, 'templates/default/fulldoc/html')
YARD::Server.register_static_path File.join(__dir__, 'docserver/default/fulldoc/html')
