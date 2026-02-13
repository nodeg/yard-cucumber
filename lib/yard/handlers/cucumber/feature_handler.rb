# frozen_string_literal: true

module YARD
  module Handlers
    module Cucumber
      class FeatureHandler < Base
        handles YARD::CodeObjects::Cucumber::Feature

        def process
          # No-op: Features are processed in the after_parse_list callback below.
          # This ensures all step definitions and transforms are loaded before we try to link them.
        end

        #
        # Post-processing callback: Links Steps to StepDefinitions and Transforms
        #
        YARD::Parser::SourceParser.after_parse_list do
          # Reset cache to ensure we don't have stale data from previous runs (e.g. in server mode)
          FeatureHandler.reset_cache

          YARD::Registry.all(:feature).each do |feature|
            log.debug "Linking steps for feature: #{feature.name}"
            FeatureHandler.match_steps(feature)
          end
        end

        class << self
          def reset_cache
            @step_definitions = nil
            @step_transforms = nil
          end

          def match_steps(feature)
            # Lazy load the cache
            cache_definitions_and_transforms unless @step_definitions

            return unless feature

            process_scenario(feature.background) if feature.background

            feature.scenarios.each do |scenario|
              if scenario.is_a?(YARD::CodeObjects::Cucumber::ScenarioOutline)
                scenario.scenarios.each { |example| process_scenario(example) }
              else
                process_scenario(scenario)
              end
            end
          rescue StandardError => e
            log.warn "Failed to link steps for feature '#{feature.name}': #{e.message}"
            log.debug e.backtrace.join("\n")
          end

          private

          def process_scenario(scenario)
            scenario.steps.each { |step| match_step(step) }
          end

          def match_step(step)
            # Find the first matching step definition
            match = @step_definitions.find do |regex, _stepdef|
              step.value.match(regex)
            end

            return unless match

            regex, stepdef_object = match
            step.definition = stepdef_object

            # Now check for Transforms on captured arguments
            match_data = step.value.match(regex)

            # Iterate over captures (if any) to see if they match a Transform
            if match_data && match_data.captures.any?
              match_data.captures.each do |captured_value|
                next unless captured_value # Skip nil captures

                @step_transforms.each do |trans_regex, trans_obj|
                  if captured_value.match(trans_regex)
                    step.transforms << trans_obj
                    trans_obj.steps << step
                  end
                end
              end
            end
          end

          def cache_definitions_and_transforms
            @step_definitions = {}
            @step_transforms = {}

            # Cache Step Definitions
            YARD::Registry.all(:stepdefinition).each do |obj|
              regex = value_to_regex(obj.value)
              @step_definitions[regex] = obj if regex
            end

            # Cache Step Transforms
            YARD::Registry.all(:steptransform).each do |obj|
              regex = value_to_regex(obj.value)
              @step_transforms[regex] = obj if regex
            end
          end

          #
          # Robustly converts a stored string value back to a Regexp object
          #
          def value_to_regex(value)
            return nil unless value.is_a?(String)

            # Clean the string if it looks like a regex source
            clean_val = value.strip

            # If it starts and ends with slash, strip them and ignore flags for now
            if clean_val.start_with?('/') && clean_val.end_with?('/')
              clean_val = clean_val[1..-2]
            end

            # If it starts with ^ or ends with $, those are valid in Regex.new

            begin
              Regexp.new(clean_val)
            rescue RegexpError
              log.warn "Invalid regex in Cucumber object: #{value}"
              nil
            end
          end
        end
      end
    end
  end
end
