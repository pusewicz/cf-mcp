# frozen_string_literal: true

# sig/ holds this gem's own signatures; sig-stubs/ holds hand-written stubs for
# dependencies that ship none (mcp, rackup, rubyzip) and one narrowed core
# signature. Third-party and stdlib signatures come from rbs_collection.yaml.

PARSERS = %w[lib/cf/mcp/parser.rb lib/cf/mcp/topic_parser.rb].freeze

# Everything except the two regex-driven parsers is checked with the strict
# template.
target :lib do
  signature "sig", "sig-stubs"
  check "lib"
  ignore(*PARSERS)

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

# The parsers are built on regex captures. RBS core types the block of
# `String#scan` as yielding `String | Array[String?]` and `Regexp.last_match` as
# nilable, so strict mode would force rewriting the parsing logic rather than
# annotating it. They still need a signature for every method and their return
# types are still checked; only the nil-flow noise from regex captures is
# downgraded (see Steep::Diagnostic::Ruby.lenient).
target :parsers do
  signature "sig", "sig-stubs"
  check(*PARSERS)

  configure_code_diagnostics(Steep::Diagnostic::Ruby.lenient) do |hash|
    hash[Steep::Diagnostic::Ruby::UndeclaredMethodDefinition] = :error
    hash[Steep::Diagnostic::Ruby::MethodDefinitionMissing] = nil
  end
end
