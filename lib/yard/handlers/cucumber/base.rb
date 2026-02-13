# frozen_string_literal: true

module YARD
  module Handlers
    module Cucumber
      #
      # Base handler for all Cucumber feature handlers.
      # It sets up the namespace for feature-specific handlers.
      #
      class Base < Handlers::Base
        # This tells YARD that these handlers process 'feature' parser output
        # (which comes from your FeatureParser/CityBuilder)
        def self.handles?(node)
          handlers.any? { |handler| node.is_a?(handler) }
        end
      end

      # Register this namespace to handle the :feature parser type
      Processor.register_handler_namespace :feature, Cucumber
    end
  end
end
