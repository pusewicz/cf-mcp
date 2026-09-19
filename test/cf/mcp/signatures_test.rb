# frozen_string_literal: true

require "test_helper"
require "rbs"
require "rbs/cli"
require "rbs/test"

# Checks sig/ against the code that is actually loaded, in both directions:
#
# * every method and constant a signature declares exists (and every constant
#   has the declared type), and
# * every method defined under lib/ has a signature.
#
# `steep check` covers the second direction for `def` but not for `attr_*`, and
# it cannot cover the first at all (see the Steepfile), so this closes both gaps.
class CF::MCP::SignaturesTest < Minitest::Test
  ROOT = File.expand_path("../../..", __dir__)
  LIB_DIR = File.join(ROOT, "lib") + "/"
  COLLECTION_DIR = File.join(ROOT, ".gem_rbs_collection")
  NAMESPACE = /\A(::)?CF::MCP(::|\z)/

  # A run that examines fewer methods than this is not really checking anything,
  # e.g. because LIB_DIR no longer matches the paths Ruby reports.
  MINIMUM_METHODS_CHECKED = 100

  class << self
    # The same signatures `steep check` and `rbs test` load: sig/, sig-stubs/ and
    # the RBS collection.
    def env
      @env ||= begin
        options = RBS::CLI::LibraryOptions.new
        options.config_path = Pathname(File.join(ROOT, "rbs_collection.yaml"))
        options.dirs.push(File.join(ROOT, "sig"), File.join(ROOT, "sig-stubs"))
        RBS::Environment.from_loader(options.loader).resolve_type_names
      end
    end

    def builder
      @builder ||= RBS::DefinitionBuilder.new(env: env)
    end
  end

  def setup
    # `rake rbs:test` re-runs the suite with the runtime type checker installed,
    # which aliases every checked method (foo__without__RBS_TEST_...) and would
    # look like undeclared methods here. The plain test run already covers this.
    skip "runs on the un-instrumented classes" if ENV.key?("RBS_TEST_TARGET")

    flunk "Run `bundle exec rbs collection install` first (or bin/setup)" unless File.directory?(COLLECTION_DIR)
  end

  def test_every_declared_method_exists
    missing = []

    declared_type_names.each do |type_name|
      mod = constant_for(type_name)
      if mod.nil?
        missing << "#{type_name} is declared but does not exist"
        next
      end

      builder.build_instance(type_name).methods.each do |name, definition|
        next unless definition.defined_in == type_name

        missing << "#{mod}##{name}" unless mod.method_defined?(name) || mod.private_method_defined?(name)
      end

      builder.build_singleton(type_name).methods.each do |name, definition|
        next unless definition.defined_in == type_name

        missing << "#{mod}.#{name}" unless mod.respond_to?(name, true)
      end
    end

    assert_empty missing, "Declared in sig/ but not defined:\n  #{missing.join("\n  ")}"
  end

  def test_every_method_defined_in_lib_is_declared
    undeclared = []
    checked = 0

    loaded_modules.each do |mod|
      type_name = RBS::TypeName.parse("::#{mod.name}")
      declared = env.class_decls.key?(type_name)

      instance_methods = declared ? builder.build_instance(type_name).methods : {}
      lib_instance_methods(mod).each do |name|
        checked += 1
        undeclared << (declared ? "#{mod}##{name}" : "#{mod}##{name} (#{mod} is not declared)") unless instance_methods.key?(name)
      end

      singleton_methods = declared ? builder.build_singleton(type_name).methods : {}
      lib_singleton_methods(mod).each do |name|
        checked += 1
        undeclared << (declared ? "#{mod}.#{name}" : "#{mod}.#{name} (#{mod} is not declared)") unless singleton_methods.key?(name)
      end
    end

    assert_operator checked, :>=, MINIMUM_METHODS_CHECKED, "Only #{checked} methods under lib/ were examined"
    assert_empty undeclared, "Defined in lib/ but not declared in sig/:\n  #{undeclared.join("\n  ")}"
  end

  def test_declared_constants_exist_with_the_declared_type
    type_check = RBS::Test::TypeCheck.new(self_class: Object, builder: builder, sample_size: 100, unchecked_classes: [])
    problems = []
    checked = 0

    env.constant_decls.each do |type_name, entry|
      next unless type_name.to_s.match?(NAMESPACE)

      checked += 1
      path = type_name.to_s.delete_prefix("::")

      unless Object.const_defined?(path)
        problems << "#{path} is declared but does not exist"
        next
      end

      value = Object.const_get(path)
      type = entry.decl.type
      problems << "#{path} is declared as #{type} but is #{value.inspect[0, 60]}" unless type_check.value(value, type)
    end

    assert_operator checked, :>, 0
    assert_empty problems, problems.join("\n")
  end

  private

  def env = self.class.env

  def builder = self.class.builder

  def declared_type_names
    env.class_decls.keys.select { |type_name| type_name.to_s.match?(NAMESPACE) }
  end

  def constant_for(type_name)
    Object.const_get(type_name.to_s.delete_prefix("::"))
  rescue NameError
    nil
  end

  # Every class and module under CF::MCP that is loaded, loading the autoloaded
  # ones on the way so nothing is skipped because it has not been referenced yet.
  def loaded_modules
    modules = [CF::MCP]
    queue = [CF::MCP]

    until queue.empty?
      mod = queue.shift
      mod.constants(false).each do |name|
        constant = mod.const_get(name)
        next unless constant.is_a?(Module) && constant.name.to_s.match?(NAMESPACE) && !modules.include?(constant)

        modules << constant
        queue << constant
      end
    end

    modules
  end

  def lib_instance_methods(mod)
    (mod.instance_methods(false) + mod.private_instance_methods(false)).select do |name|
      defined_in_lib?(mod.instance_method(name))
    end
  end

  def lib_singleton_methods(mod)
    singleton = mod.singleton_class
    (singleton.instance_methods(false) + singleton.private_instance_methods(false)).select do |name|
      defined_in_lib?(singleton.instance_method(name))
    end
  end

  def defined_in_lib?(method)
    method.source_location&.first&.start_with?(LIB_DIR) || false
  end
end
