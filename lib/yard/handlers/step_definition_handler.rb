# frozen_string_literal: true

#
# Finds and processes all the step definitions defined in the ruby source code.
# By default, English Gherkin keywords (Given, When, Then, And, But) are parsed.
#
# You can override this in `~/.yard/config` or `.yardopts`.
#
class YARD::Handlers::Ruby::StepDefinitionHandler < YARD::Handlers::Ruby::Base
  # We handle *any* method call, and then filter inside `process`
  # based on the method name. This is safer than defining dynamic
  # `handles` rules at load time.
  handles :method_call

  process do
    # 1. Guard: Check if the method name is a Step Definition keyword
    method_name = statement.method_name(true).to_s
    return unless step_definition_keywords.include?(method_name)

    # 2. Extract parameters (the regex)
    # The statement structure is s(:method_add_block, call_node, block_node)
    # We want the parameters from the call_node.
    params = statement.parameters(false)

    # 3. Create the Step Definition Object
    obj = register YARD::CodeObjects::StepDefinitionObject.new(step_transform_namespace, generate_unique_name) do |o|
      o.source   = statement.source
      o.comments = statement.comments
      o.keyword  = method_name
      o.value    = params ? params.source : ""

      # Check if the block contains the 'pending' keyword
      if statement.block
        o.pending = node_contains_pending?(statement.block)
      end
    end

    # 4. Parse the block content so that any nested transforms/objects are documented
    if statement.block
      parse_block(statement.block, owner: obj)
    end
  end

  private

  #
  # Returns the list of configured step definition keywords.
  # Defaults to standard Gherkin English keywords.
  #
  def step_definition_keywords
    @step_definition_keywords ||= begin
      config = YARD::Config.options['yard-cucumber'] || {}
      lang = config['language'] || {}
      keywords = lang['step_definitions'] || %w[Given When Then And But]
      keywords.map(&:to_s)
    end
  end

  def step_transform_namespace
    YARD::CodeObjects::Cucumber::CUCUMBER_STEPTRANSFORM_NAMESPACE
  end

  def generate_unique_name
    "step_definition#{self.class.generate_unique_id}"
  end

  def self.generate_unique_id
    @step_definition_count = (@step_definition_count || 0) + 1
  end

  #
  # AST Traversal to find 'pending' calls
  #
  def node_contains_pending?(node)
    # 'pending' is usually a :vcall (variable/method call) or :command (method with args)
    node.traverse do |child|
      if child.type == :vcall || child.type == :command
        # child[0] is the method name identifier
        return true if child[0].source == 'pending'
      end
    end
    false
  end
end
