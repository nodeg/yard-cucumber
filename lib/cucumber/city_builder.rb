# frozen_string_literal: true

module Cucumber
  module Parser
    class CityBuilder
      def initialize(file)
        @namespace = YARD::CodeObjects::Cucumber::CUCUMBER_NAMESPACE
        find_or_create_namespace(file)
        @file = file
        @feature_obj = nil
      end

      def process(document)
        feature_node = document.feature
        return nil unless feature_node

        return nil if has_exclude_tags?(feature_node.tags)

        # Create Feature Object
        @feature_obj = YARD::CodeObjects::Cucumber::Feature.new(@namespace, File.basename(@file.gsub('.feature', '').gsub('.', '_'))) do |f|
          f.comments = document.comments.map(&:text).join("\n")
          f.description = feature_node.description || ''
          f.add_file(@file, feature_node.location.line)
          f.keyword = feature_node.keyword
          f.value = feature_node.name

          # DEFENSIVE INIT: Ensure arrays are never nil
          f.tags = []
          f.scenarios = []
          f.background = nil

          feature_node.tags.each { |t| find_or_create_tag(t.name, f) }
        end

        feature_node.children.each do |child|
          if child.background
            process_background(child.background)
          elsif child.scenario
            process_scenario(child.scenario)
          elsif child.rule
            process_rule(child.rule)
          end
        end

        # Calculate stats
        @feature_obj.tags.each do |feature_tag|
          tag_code_object = YARD::Registry.all(:tag).find { |tag| tag.name.to_s == feature_tag.name.to_s }
          tag_code_object.total_scenarios += @feature_obj.total_scenarios if tag_code_object
        end

        @feature_obj
      end

      private

      def process_background(node)
        @background = YARD::CodeObjects::Cucumber::Scenario.new(@feature_obj, "background") do |b|
          b.description = node.description || ''
          b.keyword = node.keyword
          b.value = node.name
          b.add_file(@file, node.location.line)
          b.steps = [] # Defensive
          b.tags = []  # Defensive
        end

        @feature_obj.background = @background
        @background.feature = @feature_obj

        node.steps.each { |step| process_step(step, @background) }
      end

      def process_rule(node)
        node.children.each do |child|
          if child.background
            process_background(child.background)
          elsif child.scenario
            process_scenario(child.scenario)
          end
        end
      end

      def process_scenario(node)
        return if has_exclude_tags?(node.tags)

        if node.examples && !node.examples.empty?
          process_scenario_outline(node)
        else
          process_regular_scenario(node)
        end
      end

      def process_regular_scenario(node)
        scenario = YARD::CodeObjects::Cucumber::Scenario.new(@feature_obj, "scenario_#{@feature_obj.scenarios.length + 1}") do |s|
          s.description = node.description || ''
          s.add_file(@file, node.location.line)
          s.keyword = node.keyword
          s.value = node.name
          s.steps = []
          s.tags = []
          node.tags.each { |t| find_or_create_tag(t.name, s) }
        end

        scenario.feature = @feature_obj
        @feature_obj.scenarios << scenario

        node.steps.each { |step| process_step(step, scenario) }
        update_tag_stats(scenario)
      end

      def process_scenario_outline(node)
        outline = YARD::CodeObjects::Cucumber::ScenarioOutline.new(@feature_obj, "scenario_#{@feature_obj.scenarios.length + 1}") do |s|
          s.description = node.description || ''
          s.add_file(@file, node.location.line)
          s.keyword = node.keyword
          s.value = node.name
          s.steps = []
          s.tags = []
          s.examples = [] # Defensive
          node.tags.each { |t| find_or_create_tag(t.name, s) }
        end

        outline.feature = @feature_obj

        node.steps.each { |step| process_step(step, outline) }
        node.examples.each { |ex| process_examples(ex, outline) }

        @feature_obj.scenarios << outline
        @feature_obj.total_scenarios += outline.scenarios.size # This assumes scenarios are populated by examples

        update_tag_stats(outline, outline.scenarios.size)
      end

      def process_step(node, parent)
        parent.steps ||= []

        step_obj = YARD::CodeObjects::Cucumber::Step.new(parent, "#{node.location.line}") do |s|
          s.keyword = node.keyword
          s.value = node.text
          s.add_file(@file, node.location.line)
          s.text = nil
          s.table = nil
        end

        step_obj.text = node.doc_string.content if node.doc_string
        step_obj.table = node.data_table.rows.map { |row| row.cells.map(&:value) } if node.data_table

        step_obj.scenario = parent
        parent.steps << step_obj
      end

      def process_examples(example_node, outline)
        return if has_exclude_tags?(example_node.tags)

        # Ensure a valid name is generated if missing
        ex_name = (example_node.name && !example_node.name.empty?) ? example_node.name : "examples_#{outline.examples.length}"

        example = YARD::CodeObjects::Cucumber::ScenarioOutline::Examples.new(outline, ex_name) do |e|
          e.keyword = example_node.keyword
          e.value = example_node.name || ""
          e.add_file(@file, example_node.location.line)
          e.rows = []
          e.tags = []
          e.scenario = outline
        end

        example_node.tags.each { |t| find_or_create_tag(t.name, example) }

        headers = []
        if example_node.table_header
          headers = example_node.table_header.cells.map(&:value)
          example.rows = [headers]
        end

        if example_node.table_body
          example.rows += example_node.table_body.map { |row| row.cells.map(&:value) }
        end

        outline.examples << example

        # Explode examples
        if example_node.table_body
          example_node.table_body.each_with_index do |row, row_index|
            create_scenario_from_example(outline, headers, row, row_index)
          end
        end
      end

      def create_scenario_from_example(outline, headers, row_data, index)
        scenario = YARD::CodeObjects::Cucumber::Scenario.new(outline, "example_#{outline.scenarios.length + 1}") do |s|
          s.comments = outline.comments
          s.description = outline.description
          s.add_file(@file, outline.line)
          s.keyword = outline.keyword
          s.value = "#{outline.value} (#{outline.scenarios.length + 1})"
          s.steps = []
          s.tags = []
        end

        outline.steps.each do |step|
          step_instance = YARD::CodeObjects::Cucumber::Step.new(scenario, "#{step.line}_copy_#{index}") do |s|
            s.keyword = step.keyword.dup
            s.value = step.value.dup
            s.add_file(@file, step.line)
            s.text = step.text.dup if step.text
            s.table = clone_table(step.table) if step.table
          end

          # Substitution
          row_values = row_data.cells.map(&:value)
          headers.each_with_index do |header, col_index|
            val = row_values[col_index] || ""
            step_instance.value.gsub!("<#{header}>", val)
            step_instance.text.gsub!("<#{header}>", val) if step_instance.text
            step_instance.table.each { |r| r.each { |c| c.gsub!("<#{header}>", val) } } if step_instance.table
          end

          step_instance.scenario = scenario
          scenario.steps << step_instance
        end

        scenario.feature = @feature_obj
        outline.scenarios << scenario
      end

      # ------------------------------------------------------------------------
      # Helpers
      # ------------------------------------------------------------------------

      def find_or_create_namespace(file)
        @namespace = YARD::CodeObjects::Cucumber::CUCUMBER_NAMESPACE

        File.dirname(file).split('/').each do |directory|
          next if directory == "."
          @namespace = @namespace.children.find { |child| child.is_a?(YARD::CodeObjects::Cucumber::FeatureDirectory) && child.name.to_s == directory } ||
                       YARD::CodeObjects::Cucumber::FeatureDirectory.new(@namespace, directory) { |dir| dir.add_file(directory) }
        end

        readme_path = File.join(File.dirname(file), 'README.md')
        if @namespace.description == "" && File.exist?(readme_path)
          @namespace.description = File.read(readme_path)
        end
      end

      def find_or_create_tag(tag_name, parent)
        parent.tags ||= []
        clean_name = tag_name.gsub('@', '')
        tag_code_object = YARD::Registry.all(:tag).find { |tag| tag.value == tag_name } ||
                          YARD::CodeObjects::Cucumber::Tag.new(YARD::CodeObjects::Cucumber::CUCUMBER_TAG_NAMESPACE, clean_name) do |t|
                            t.owners = []
                            t.value = tag_name
                            t.total_scenarios = 0
                          end

        tag_code_object.add_file(@file, parent.line)

        parent.tags << tag_code_object unless parent.tags.include?(tag_code_object)
        tag_code_object.owners << parent unless tag_code_object.owners.include?(parent)
      end

      def update_tag_stats(scenario, count=1)
        scenario.tags.uniq.each do |scenario_tag|
          unless scenario.feature.tags.include?(scenario_tag)
            tag_code_object = YARD::Registry.all(:tag).find { |tag| tag.name.to_s == scenario_tag.name.to_s }
            tag_code_object.total_scenarios += count if tag_code_object
          end
        end
      end

      def has_exclude_tags?(tags)
        return false unless tags
        tag_names = tags.map { |t| t.name.gsub(/^@/, '') }
        if YARD::Config.options["yard-cucumber"] && YARD::Config.options["yard-cucumber"]["exclude_tags"]
          !(YARD::Config.options["yard-cucumber"]["exclude_tags"] & tag_names).empty?
        else
          false
        end
      end

      def clone_table(base)
        base.map { |row| row.map(&:dup) }
      end
    end
  end
end
