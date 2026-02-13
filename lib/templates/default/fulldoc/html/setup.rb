include YARD::Templates::Helpers::HtmlHelper

def init
  super

  # Additional javascript that power the additional menus, collapsing, etc.
  asset "js/cucumber.js", file("js/cucumber.js",true)

  serialize_object_type :feature
  serialize_object_type :tag

  # Generates the requirements splash page with the 'requirements' template
  serialize(YARD::CodeObjects::Cucumber::CUCUMBER_NAMESPACE)

  # Generates a page for step definitions and step transforms with the 'steptransformers' template
  serialize(YARD::CodeObjects::Cucumber::CUCUMBER_STEPTRANSFORM_NAMESPACE)

  # Generates the tags page with the 'featuretags' template
  serialize(YARD::CodeObjects::Cucumber::CUCUMBER_TAG_NAMESPACE)

  serialize_feature_directories
end

def root_feature_directories
  @root_feature_directories ||= YARD::CodeObjects::Cucumber::CUCUMBER_NAMESPACE.children.find_all {|child| child.is_a?(YARD::CodeObjects::Cucumber::FeatureDirectory)}
end

def serialize_object_type(type)
  objects = Registry.all(type.to_sym)
  Array(objects).each {|object| serialize(object) }
end

def serialize_feature_directories
  serialize_feature_directories_recursively(root_feature_directories)
  root_feature_directories.each {|directory| serialize(directory) }
end

def serialize_feature_directories_recursively(namespaces)
  namespaces.each do |namespace|
    Templates::Engine.with_serializer(namespace, options[:serializer]) do
      options[:object] = namespace
      T('layout').run(options)
    end
    serialize_feature_directories_recursively(namespace.children.find_all {|child| child.is_a?(YARD::CodeObjects::Cucumber::FeatureDirectory)})
  end
end

def generate_feature_list
  features = Registry.all(:feature)
  features_ordered_by_name = features.sort {|x,y| x.value.to_s <=> y.value.to_s }
  generate_full_list features_ordered_by_name, :features
end

def record_feature_scenarios(features)
  count_with_examples = 0
  features.each do |f|
    count_with_examples += f.total_scenarios
  end
  return count_with_examples
end

def record_tagged_scenarios(tags)
  scenario_count = 0
  count_with_examples = 0
  tags.each do |t|
    scenario_count += t.all_scenarios.size if t.respond_to?(:all_scenarios)
    count_with_examples += t.total_scenarios
  end
end

def generate_tag_list
  tags = Registry.all(:tag)
  tags_ordered_by_use = Array(tags).sort {|x,y| y.total_scenarios <=> x.total_scenarios }

  record_tagged_scenarios(tags)

  generate_full_list tags_ordered_by_use, :tags
end

def generate_stepdefinition_list
  generate_full_list YARD::Registry.all(:stepdefinition), :stepdefinitions,
    :list_title => "Step Definitions List"
end

def generate_step_list
  generate_full_list YARD::Registry.all(:step), :steps
end

def generate_featuredirectories_list
  directories_ordered_by_name = root_feature_directories.sort {|x,y| x.value.to_s <=> y.value.to_s }
  generate_full_list directories_ordered_by_name, :featuredirectories,
    :list_title => "Features by Directory",
    :list_filename => "featuredirectories_list.html"
end

def generate_full_list(objects,type,options = {})
  defaults = { :list_title => "#{type.to_s.capitalize} List",
    :css_class => "class",
    :list_filename => "#{type.to_s.gsub(/s$/,'')}_list.html" }

  options = defaults.merge(options)

  @items = objects
  @list_type = type
  @list_title = options[:list_title]
  @list_class = options[:css_class]
  asset options[:list_filename], erb(:full_list)
end

#
# FIXED: Using *args allows us to accept whatever arguments YARD passes (root, tree)
# without needing to explicitly name the 'TreeContext' class, which is missing.
#
def class_list(*args)
  root = args.first || Registry.root

  # Only interfere if we are looking at the root registry
  return super unless root == Registry.root

  cucumber_namespace = YARD::CodeObjects::Cucumber::CUCUMBER_NAMESPACE

  # Safely hide the Cucumber namespace from the class list
  if root.children.include?(cucumber_namespace)
    root.children.delete(cucumber_namespace)
    out = super # Implicitly passes *args
    root.children.push(cucumber_namespace)
    out
  else
    super
  end
end

def all_features_link
  features = Registry.all(:feature)
  count_with_examples = record_feature_scenarios(features)
  if root_feature_directories.length == 0 || root_feature_directories.length > 1
    linkify YARD::CodeObjects::Cucumber::CUCUMBER_NAMESPACE, "All Features (#{count_with_examples})"
  else
    linkify root_feature_directories.first, "All Features (#{count_with_examples})"
  end
end

def directory_node(directory,padding,row)
  @directory = directory
  @padding = padding
  @row = row
  erb(:directories)
end
