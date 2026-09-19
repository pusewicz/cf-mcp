# frozen_string_literal: true

# sig/ holds this gem's own signatures; sig-stubs/ holds hand-written stubs for
# dependencies that ship none (mcp, rackup, rubyzip) and one narrowed core
# signature. Third-party and stdlib signatures come from rbs_collection.yaml.
target :lib do
  signature "sig", "sig-stubs"
  check "lib"

  configure_code_diagnostics(Steep::Diagnostic::Ruby.strict) do |hash|
    # Coverage gate: a Ruby method with no signature. The strict template only
    # makes this a warning.
    hash[Steep::Diagnostic::Ruby::UndeclaredMethodDefinition] = :error

    # The opposite direction (a signature with no Ruby method) can't be enforced
    # here: Steep doesn't treat attr_* calls as definitions, and it reports every
    # declared method again in each file that reopens a module. That direction,
    # and undeclared attr_* methods, are checked at runtime by
    # test/cf/mcp/signatures_test.rb instead.
    hash[Steep::Diagnostic::Ruby::MethodDefinitionMissing] = nil
  end
end
