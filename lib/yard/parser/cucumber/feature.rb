# frozen_string_literal: true

require 'gherkin'

module YARD
  module Parser
    module Cucumber
      class FeatureParser < YARD::Parser::Base
        #
        # Each found feature creates a new FeatureParser.
        #
        # @param [String] source containing the string contents of the feature file
        # @param [String] file the filename that contains the source
        #
        def initialize(source, file = '(stdin)')
          @source = source
          @file = file
          @feature = nil
        end

        #
        # Parses the source using the modern Gherkin AST walker.
        #
        def parse
          # MODERN GHERKIN API (v20+ / Cucumber 10+):
          # Gherkin.from_source(source_text, options)
          # We pass the URI inside the options hash.

          options = {
            uri: @file,
            include_source: false,
            include_gherkin_document: true,
            include_pickles: false
          }

          # 1. Parse the raw Gherkin text into a stream of messages
          messages = ::Gherkin.from_source(@source, options)

          # 2. Extract the GherkinDocument (the root of the AST)
          # Messages are an Enumerator, convert to Array to find the doc
          document = messages.to_a.find(&:gherkin_document)&.gherkin_document

          return nil unless document&.feature

          # 3. Pass the AST to our CityBuilder to generate YARD objects
          builder = ::Cucumber::Parser::CityBuilder.new(@file)
          @feature = builder.process(document)

          self
        rescue => e
          # Log the specific error but don't crash YARD
          # This helps you debug which specific feature file is broken
          log.warn "Failed to parse #{@file}: #{e.message}"
          log.debug e.backtrace.join("\n")
          nil
        end

        def tokenize
          []
        end

        def enumerator
          [@feature]
        end
      end

      # Register the parser
      YARD::Parser::SourceParser.register_parser_type :feature, FeatureParser, 'feature'
    end
  end
end
