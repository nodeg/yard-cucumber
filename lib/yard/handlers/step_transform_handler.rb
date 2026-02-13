# frozen_string_literal: true

#
# Processes Cucumber Transform and ParameterType definitions.
#
# Examples handled:
#   Transform /^(\d+)$/ do |num| ... end
#   ParameterType(name: 'color', regexp: /red|blue/, transformer: ->(s) { ... })
#
class YARD::Handlers::Ruby::StepTransformHandler < YARD::Handlers::Ruby::Base
  handles method_call(:Transform)
  handles method_call(:ParameterType)

  process do
    method_name = statement.method_name(true).to_s

    # Calculate the name (either unique ID or linked to a constant owner)
    name = step_transformer_name

    # Register the object
    obj = register YARD::CodeObjects::StepTransformObject.new(step_transform_namespace, name) do |o|
      o.source   = statement.source
      o.comments = statement.comments
      o.keyword  = method_name
    end

    # Retrieve parameters (returns an Array of AST nodes)
    params = statement.parameters(false)

    if method_name == 'Transform'
      process_transform(obj, params)
    elsif method_name == 'ParameterType'
      process_parameter_type(obj, params)
    end
  end

  private

  def process_transform(obj, params)
    return unless params && !params.empty?

    # The first argument is the Regex (or string representation of it)
    # params is an Array, so we take the first element.
    first_arg = params.first

    if first_arg
      obj.value = clean_regex(first_arg.source)
    end

    # Parse the block attached to the method call
    if statement.block
      parse_block(statement.block, owner: obj)
    end
  end

  def process_parameter_type(obj, params)
    return unless params

    # ParameterType arguments usually come in as a Hash (bare_assoc_hash)
    # We iterate through the params array to find the hash node.
    hash_node = params.find { |p| p.type == :bare_assoc_hash || p.type == :assoclist_from_args }
    return unless hash_node

    # Find specific keys in the arguments hash
    regexp_node = find_key_in_hash(hash_node, 'regexp')
    transformer_node = find_key_in_hash(hash_node, 'transformer')

    if regexp_node
      obj.value = clean_regex(regexp_node.source)
    end

    # If a transformer proc is provided, parse it as the "block"
    if transformer_node
      parse_block(transformer_node, owner: obj)
    end
  end

  #
  # Helpers
  #

  def step_transform_namespace
    YARD::CodeObjects::Cucumber::CUCUMBER_STEPTRANSFORM_NAMESPACE
  end

  def step_transformer_name
    # If the owner is a constant (set by ConstantTransformHandler),
    # we use the constant's name so they link together.
    if owner.is_a?(YARD::CodeObjects::ConstantObject)
      owner.name
    else
      "step_transform#{self.class.generate_unique_id}"
    end
  end

  def self.generate_unique_id
    @step_transformer_count = (@step_transformer_count || 0) + 1
  end

  #
  # AST Helper: Find a specific key in a Hash AST node
  # Handles both `key: value` (label) and `:key => value` (symbol)
  #
  def find_key_in_hash(hash_node, key_name)
    hash_node.children.each do |pair|
      key = pair[0]
      value = pair[1]

      # Check for label "key:" or symbol ":key"
      if (key.type == :label && key.source == "#{key_name}:") ||
         (key.type == :symbol_literal && key.source == ":#{key_name}")
        return value
      end
    end
    nil
  end

  #
  # Cleans the regex string for display (removes anchors and slashes)
  #
  def clean_regex(source)
    source.gsub(/(^\(?\/|\/\)?$)/, '') # Strip start/end slashes
          .gsub(/(^\^|\$$)/, '')        # Strip anchors
  end
end
