# frozen_string_literal: true

#
# This handler intercepts constant assignments that use Cucumber's Transform or ParameterType methods.
# It registers them as constants but updates their documentation to link to the underlying
# StepTransform object, preventing the constant's value from being overridden by the default handler.
#
class YARD::Handlers::Ruby::ConstantTransformHandler < YARD::Handlers::Ruby::ConstantHandler
  include YARD::Handlers::Ruby::StructHandlerMethods

  handles :assign
  namespace_only

  process do
    # statement is s(:assign, LHS, RHS)
    lhs = statement[0]
    rhs = statement[1]

    # Guard: We only care about assignments to constants
    return unless lhs.type == :var_field && lhs[0].type == :const

    # Extract method name from RHS (Transform or ParameterType)
    method_name = extract_method_name(rhs)
    return unless %w[Transform ParameterType].include?(method_name)

    const_name = lhs[0].source

    # Extract the value (Regex or String) based on the method type
    value_node = extract_transform_value(rhs, method_name)

    # Prepare the cleaned value for the constant
    final_value = if value_node
                    val = substitute(value_node.source)
                    val = strip_anchors(val)
                    convert_captures(val)
                  else
                    "UNABLE_TO_PARSE_TRANSFORM"
                  end

    # Register the Constant Object
    # We do this manually to ensure we control the docstring and source
    object = register ConstantObject.new(namespace, const_name)
    object.source = statement
    object.value = final_value

    # Update docstring to reference the Transform object
    # The actual Transform object is likely created by a separate StepTransformHandler processing the block
    object.docstring = "Reference to {#{YARD::CodeObjects::Cucumber::CUCUMBER_STEPTRANSFORM_NAMESPACE}::#{const_name} transform}"

    # If the assignment has a block (e.g. Transform /.../ do ... end),
    # we must parse the block so the StepDefinition/Transform handlers can see it.
    # We pass 'owner: object' so the transform knows it belongs to this constant.
    if rhs.type == :method_add_block
      parse_block(rhs[1], owner: object)
    end
  end

  private

  #
  # Robustly extracts the method name from the RHS of an assignment
  # Handles: Transform(...) and Transform(...) { block }
  #
  def extract_method_name(node)
    # Unwrap method_add_block (method call + block)
    node = node[0] if node.type == :method_add_block

    # Unwrap method_add_arg (method call + arguments)
    node = node[0] if node.type == :method_add_arg

    # Check if it is a function call
    return node[0].source if node.type == :fcall && node[0].type == :ident

    nil
  end

  #
  # Extracts the Regex or Value argument from the method call
  #
  def extract_transform_value(node, method_name)
    # Get to the arguments node
    # Structure: s(:method_add_block, s(:method_add_arg, CALL, ARGS), BLOCK)
    call_chain = node.type == :method_add_block ? node[0] : node

    # args is usually s(:arg_paren, s(:args_add_block, ...)) or direct args list
    args = call_chain[1]
    return nil unless args

    if method_name == 'Transform'
      # Transform /regex/
      # The first argument is the regex
      first_arg = find_first_argument(args)
      return first_arg
    elsif method_name == 'ParameterType'
      # ParameterType(name: '...', regexp: /.../, ...)
      # We need to find the 'regexp:' key in the hash arguments
      return find_parameter_type_regexp(args)
    end
    nil
  end

  def find_first_argument(args_node)
    # args_node structure varies by ruby version/parser state, usually:
    # s(:args_add_block, s(:args_new, ARG), false)
    return args_node[0][0] if args_node.type == :args_add_block && args_node[0].type == :args_new

    # Fallback traverse
    args_node.jump(:regexp_literal, :string_literal)
  end

  def find_parameter_type_regexp(args_node)
    # Scan arguments for a Hash (bare_assoc_hash)
    args_node.traverse do |node|
      next unless node.type == :bare_assoc_hash

      # Iterate through pairs s(:assoc_new, KEY, VALUE)
      node.children.each do |pair|
        key = pair[0]
        value = pair[1]

        # Match 'regexp:' label or ':regexp' symbol
        if (key.type == :label && key.source == 'regexp:') ||
           (key.type == :symbol_literal && key.source == ':regexp')
           return value
        end
      end
    end
    nil
  end

  #
  # Cucumber Regex Helpers
  #

  def convert_captures(regexp_source)
    regexp_source
      .gsub(/(\()(?!\?[<:=!])/, '(?:') # Non-capturing groups
      .gsub(/(\(\?<)(?![=!])/, '(?:<')
  end

  def strip_anchors(regexp_source)
    regexp_source
      .gsub(/(^\(\/|\/\)$)/, '') # Strip leading/trailing slashes
      .gsub(/(^\^|\$$)/, '')     # Strip anchors ^ and $
  end

  def substitute(data)
    # Handle #{Constant} interpolation in regex
    loop do
      nested = constants_from_value(data)
      break if nested.empty?

      nested.each do |n|
        val = find_value_for_constant(n)
        data = data.gsub(value_regex(n), val)
      end
    end
    data
  end

  def constants_from_value(data)
    data.scan(/#\{\s*(\w+)\s*\}/).flatten.map(&:strip)
  end

  def value_regex(value)
    /#\{\s*#{value}\s*\}/
  end

  def find_value_for_constant(name)
    constant = YARD::Registry.all(:constant).find { |c| c.name == name.to_sym }
    unless constant
      # Log warning but don't crash
      log.warn "ConstantTransformHandler: Could not resolve interpolated constant [#{name}]"
      return name
    end
    strip_regex_from(constant.value)
  end

  def strip_regex_from(value)
    value.gsub(/^\/|\/$/, '')
  end
end
