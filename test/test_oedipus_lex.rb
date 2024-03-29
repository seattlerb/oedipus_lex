require "minitest/autorun"
require "oedipus_lex"
require "stringio"

class TestOedipusLex < Minitest::Test
  attr_accessor :option

  def setup
    self.option = {}
  end

  def generate_lexer grammar
    rex = OedipusLex.new option
    rex.parse cleanup grammar
    rex.generate
  end

  def assert_generate_error grammar, expected_msg
    rex = OedipusLex.new option

    e = assert_raises OedipusLex::ScanError do
      rex.parse cleanup grammar
    end

    assert_match expected_msg, e.message
  end

  def cleanup s
    s.gsub(/^ {6}/, "")
  end

  def eval_lexer grammar
    ruby = generate_lexer grammar

    if option[:wtf]
      puts
      puts ruby
      puts
    end

    mod = Module.new
    mod.module_eval ruby

    return ruby, mod
  end

  def assert_lexer grammar, input, expected
    _, mod = eval_lexer grammar

    calc = mod::Calculator.new

    def calc.do_parse
      tokens = []
      while token = next_token
        tokens << token
      end
      tokens
    end

    tokens = calc.parse input

    assert_equal expected, tokens
  end

  def assert_lexer_error grammar, input, expected_msg
    _, mod = eval_lexer grammar

    calc = mod::Calculator.new

    def calc.do_parse
      tokens = []
      while token = next_token
        tokens << token
      end
      tokens
    end

    e = assert_raises mod::Calculator::ScanError do
      calc.parse input
    end

    assert_equal expected_msg, e.message
  end

  def assert_token_error grammar, input, expected_msg
    _, mod = eval_lexer grammar

    calc = mod::Calculator.new

    def calc.do_parse
      tokens = []
      while token = next_token
        tokens << token
      end
      tokens
    end

    e = assert_raises mod::Calculator::LexerError do
      calc.parse input
    end

    assert_equal expected_msg, e.message
  end

  def test_simple_scanner
    src = <<-'REX'
      class Calculator
      rule
        /\d+/       { [:number, text.to_i] }
        /\s+/
        /[+-]/      { [:op, text] }
      end
    REX

    txt = "1 + 2 + 3"

    exp = [[:number, 1],
           [:op, "+"],
           [:number, 2],
           [:op, "+"],
           [:number, 3]]

    assert_lexer src, txt, exp
  end

  def test_simple_scanner_bug_trailing_comment
    src = <<-'REX'
      class Calculator
      rule
        /\d+/       { [:number, text.to_i] } # numbers
        /\s+/       # do nothing
        /[+-]/      { [:op, text] }
      end
    REX

    txt = "1 + 2 + 3"

    exp = [[:number, 1],
           [:op, "+"],
           [:number, 2],
           [:op, "+"],
           [:number, 3]]

    assert_lexer src, txt, exp
  end

  def test_simple_scanner_multiline_action_error
    src = <<-'REX'
      class Calculator
      rule
        /\d+/       {
                      [:number, text.to_i]
                    }
        /\s+/
        /[+-]/      { [:op, text] }
      end
    REX

    assert_generate_error src, "can not match (:rule) at <input>:4:0: '"
  end

  def test_simple_scanner_macro
    src = <<-'REX'
      class Calculator
      macro
        N /\d+/
      rule
        /#{N}/      { [:number, text.to_i] }
        /\s+/
        /[+-]/      { [:op, text] }
      end
    REX

    txt = "1 + 2 + 30"

    exp = [[:number, 1],
           [:op, "+"],
           [:number, 2],
           [:op, "+"],
           [:number, 30]]

    assert_lexer src, txt, exp
  end

  def test_simple_scanner_macro_slashes
    src = <<-'REX'
      class Calculator
      macro
        N /\d+/i
      rule
        /#{N}/o     { [:number, text.to_i] }
        /\s+/
        /[+-]/      { [:op, text] }
      end
    REX

    txt = "1 + 2 + 30"

    exp = [[:number, 1],
           [:op, "+"],
           [:number, 2],
           [:op, "+"],
           [:number, 30]]

    assert_lexer src, txt, exp
  end

  def test_simple_scanner_macro_slash_n_generator
    src = <<-'REX'
      class Calculator
      macro
        N /\d+/n
      rule
        /#{N}/o     { [:number, text.to_i] }
        /\s+/
        /[+-]/      { [:op, text] }
      end
    REX

    ruby = generate_lexer src

    assert_match "/\\d+/n", ruby
  end

  def test_simple_scanner_recursive_macro
    src = <<-'REX'
      class Calculator
      macro
        D /\d/
        N /#{D}+/
      rule
        /#{N}/      { [:number, text.to_i] }
        /\s+/
        /[+-]/      { [:op, text] }
      end
    REX

    txt = "1 + 2 + 30"

    exp = [[:number, 1],
           [:op, "+"],
           [:number, 2],
           [:op, "+"],
           [:number, 30]]

    assert_lexer src, txt, exp
  end

  def test_simple_scanner_debug_arg
    src = <<-'REX'
      class Calculator
      rule
              /\d+/       { [:number, text.to_i] }
              /\s+/
              /[+-]/      { [:op, text] }
      end
    REX

    txt = "1 + 2 + 30"

    exp = [[:number, 1],
           [:op, "+"],
           [:number, 2],
           [:op, "+"],
           [:number, 30]]

    option[:debug] = true

    out, err = capture_io do
      assert_lexer src, txt, exp
    end

    exp = exp.zip([nil]).flatten(1) # ugly, but much more compact
    exp.pop # remove last nil
    exp = exp.map(&:inspect).join("\n") + "\n"

    assert_equal "", err
    assert_match "[:number, 1]", out
    assert_match "[:op, \"+\"]", out
  end

  def test_column
    src = <<-'REX'
      class Calculator
      rule
              /\d+/       { [:number, text.to_i, lineno, column] }
              /\s+/
              /[+-]/      { [:op, text, lineno, column] }
      end
    REX

    txt = "1 + 2\n+ 30"

    exp = [[:number, 1,   1, 0],
           [:op,     "+", 1, 2],
           [:number, 2,   1, 4],
           [:op,     "+", 2, 0],
           [:number, 30,  2, 2]]

    option[:column] = true
    option[:lineno] = true

    assert_lexer src, txt, exp
  end

  def test_simple_scanner_debug_src
    src = <<-'REX'
      class Calculator
      option
        debug
      rule
              /\d+/       { [:number, text.to_i] }
              /\s+/
              /[+-]/      { [:op, text] }
      end
    REX

    txt = "1 + 2 + 30"

    exp = [[:number, 1],
           [:op, "+"],
           [:number, 2],
           [:op, "+"],
           [:number, 30]]

    out, err = capture_io do
      assert_lexer src, txt, exp
    end

    exp = exp.zip([nil]).flatten(1) # ugly, but much more compact
    exp.pop # remove last nil
    exp = exp.map(&:inspect).join("\n") + "\n"

    assert_equal "", err
    assert_match "[:number, 1]", out
    assert_match "[:op, \"+\"]", out
  end

  def test_simple_scanner_inclusive
    src = <<-'REX'
      class Calculator
      rule
              /\d+/       { [:number, text.to_i] }
              /\s+/
              /[+-]/      { @state = :op; [:op, text] }

      # nil state always goes first, so we won't get this
      :op     /\d+/       { @state = nil; [:bad, text.to_i] }
      end
    REX

    txt = "1 + 2 + 30"

    exp = [[:number, 1],
           [:op, "+"],
           [:number, 2],
           [:op, "+"],
           [:number, 30]]

    assert_lexer src, txt, exp
  end

  def test_simple_scanner_exclusive
    src = <<-'REX'
      class Calculator
      rule
              /\d+/       { [:number, text.to_i] }
              /\s+/
              /[+-]/      { @state = :OP; [:op, text] }

      :OP     /\s+/
      :OP     /\d+/       { @state = nil; [:number2, text.to_i] }
      end
    REX

    txt = "1 + 2 + 30"

    exp = [[:number, 1],
           [:op, "+"],
           [:number2, 2],
           [:op, "+"],
           [:number2, 30]]

    assert_lexer src, txt, exp
  end

  def test_simple_scanner_auto_action
    src = <<-'REX'
      class Calculator
      rule
              /rpn/       { [:state, :RPN] }
              /\d+/       { [:number, text.to_i] }
              /\s+/
              /[+-]/      { [:op, text] }

      :RPN    /\s+/
      :RPN    /[+-]/      { [:op2, text] }
      :RPN    /\d+/       { [:number2, text.to_i] }
      :RPN    /alg/       { [:state, nil] }
      end
    REX

    txt = "rpn 1 2 30 + + alg"

    exp = [[:state, :RPN],
           [:number2, 1],
           [:number2, 2],
           [:number2, 30],
           [:op2, "+"],
           [:op2, "+"],
           [:state, nil]]

    assert_lexer src, txt, exp
  end

  def test_simple_scanner_auto_action_symbol
    src = <<-'REX'
      class Calculator
      rule
              /rpn/       :RPN
              /\d+/       { [:number, text.to_i] }
              /\s+/
              /[+-]/      { [:op, text] }

      :RPN    /\s+/
      :RPN    /[+-]/      { [:op2, text] }
      :RPN    /\d+/       { [:number2, text.to_i] }
      :RPN    /alg/       nil
      end
    REX

    txt = "rpn 1 2 30 + + alg"

    exp = [[:state, :RPN],
           [:number2, 1],
           [:number2, 2],
           [:number2, 30],
           [:op2, "+"],
           [:op2, "+"],
           [:state, nil]]

    assert_lexer src, txt, exp
  end

  def test_simple_scanner_predicate_generator
    src = <<-'REX'
      class Calculator
      rules

              /\d+/       { [:number, text.to_i] }
              /\s+/
        :ARG  /\d+/
        poot? /[+-]/      { [:bad1, text] }
        woot? /[+-]/      { [:op, text] }
      end
    REX

    ruby = generate_lexer src

    assert_match "when poot? && (text = ss.scan(/[+-]/)) then", ruby
    assert_match "when woot? && (text = ss.scan(/[+-]/)) then", ruby
    assert_match "when nil then", ruby
    assert_match "when :ARG then", ruby
  end

  def test_simple_scanner_group
    src = <<-'REX'
      class Calculator
      rules

        : /\d/
        |     /\d+\.\d+/  { [:float, text.to_f] }
        |     /\d+/       { [:int, text.to_i] }
              /\s+/
      end
    REX

    ruby = generate_lexer src

    assert_match "when ss.match?(/\\d/) then", ruby
    assert_match "when text = ss.scan(/\\d+\\.\\d+/) then", ruby
    assert_match "when text = ss.scan(/\\d+/) then", ruby
    assert_match "end # group /\\d/", ruby
  end

  def test_simple_scanner_group_I_am_dumb
    src = <<-'REX'
      class Calculator
      rules

        : /\d/
        |     /\d+\.\d+/  { [:float, text.to_f] }
        |     /\d+/       { [:int, text.to_i] }
        : /\+/
        | xx? /\+whatever/  { [:x, text] }
        | :x  /\+\d+/       { [:y, text] }
              /\s+/
      end
    REX

    ruby = generate_lexer src

    assert_match "when ss.match?(/\\d/) then", ruby
    assert_match "when text = ss.scan(/\\d+\\.\\d+/) then", ruby
    assert_match "when text = ss.scan(/\\d+/) then", ruby
    assert_match "end # group /\\d/", ruby

    assert_match "when ss.match?(/\\+/) then", ruby
    assert_match "when xx? && (text = ss.scan(/\\+whatever/)) then", ruby
    assert_match "when (state == :x) && (text = ss.scan(/\\+\\d+/)) then", ruby
    assert_match "end # group /\\d/", ruby
  end

  def test_scanner_inspect_slash_structure
    src = <<-'REX'
      class Calculator
      rules

        : /\d/
        |     /\d+\.\d+/  { [:float, text.to_f] }
        |     /\d+/       { [:int, text.to_i] }
        : /\+/
        | xx? /\+whatever/  { [:x, text] }
        | :x  /\+\d+/       { [:y, text] }
        | :x  /\+\w+/       { [:z, text] }
              /\s+/
      end
    REX

    rex = OedipusLex.new option
    rex.parse cleanup src

    lex = OedipusLex
    group, rule = lex::Group, lex::Rule
    expected = lex["Calculator",
                   group[/\d/,
                         rule[nil, /\d+\.\d+/, "{ [:float, text.to_f] }"],
                         rule[nil, /\d+/, "{ [:int, text.to_i] }"]],
                   group[/\+/,
                         rule["xx?", /\+whatever/, "{ [:x, text] }"],
                         rule[":x", /\+\d+/, "{ [:y, text] }"],
                         rule[":x", /\+\w+/, "{ [:z, text] }"]],
                   rule[nil, /\s+/, nil]]

    assert_equal expected, rex
  end

  make_my_diffs_pretty!

  def test_generator_start
    src = <<-'REX'
      class Calculator
      start
        do_the_thing
      rules
              /\d+/       { [:number, text.to_i] }
              /\s+/
      end
    REX

    ruby = generate_lexer src

    assert_match "  def next_token\n    do_the_thing", ruby
  end

  def test_simple_scanner_predicate
    src = <<-'REX'
      class Calculator
      inner
        def woot?
          true
        end
        def poot?
          false
        end

      rules

              /\d+/       { [:number, text.to_i] }
              /\s+/
        poot? /[+-]/      { [:bad1, text] }
        woot? /[+-]/      { [:op, text] }
      end
    REX

    txt = "1 + 2 + 30"

    exp = [[:number, 1],
           [:op, "+"],
           [:number, 2],
           [:op, "+"],
           [:number, 30]]

    assert_lexer src, txt, exp
  end

  def test_simple_scanner_method_actions
    src = <<-'REX'
      class Calculator
      inner
        def thingy text
          [:number, text.to_i]
        end
      rule
              /\d+/       thingy
              /\s+/
              /[+-]/      { [:op, text] }
      end
    REX

    txt = "1 + 2 + 30"

    exp = [[:number, 1],
           [:op, "+"],
           [:number, 2],
           [:op, "+"],
           [:number, 30]]

    assert_lexer src, txt, exp
  end

  def test_header_is_written_after_module
    src = <<-'REX'
      module X
      module Y
      class Calculator
      rule
        /\d+/       { [:number, text.to_i] }
        /\s+/
        /[+-]/      { [:op, text] }
      end
      end
      end
    REX

    ruby = generate_lexer src

    exp = ["# frozen_string_literal: true",
           "# encoding: UTF-8",
           "#--",
           "# This file is automatically generated. Do not modify it.",
           "# Generated by: oedipus_lex version #{OedipusLex::VERSION}.",
           "#++",
           "",
           "module X",
           "module Y"]

    assert_equal exp, ruby.lines.map(&:chomp).first(9)
  end

  def test_header_encoding_is_on_top
    src = <<-'REX'
      # encoding: UTF-8

      module X
      module Y
      class Calculator
      rule
        /\d+/       { [:number, text.to_i] }
        /\s+/
        /[+-]/      { [:op, text] }
      end
      end
      end
    REX

    ruby = generate_lexer src

    exp = ["# frozen_string_literal: true",
           "# encoding: UTF-8",
           "#--",
           "# This file is automatically generated. Do not modify it.",
           "# Generated by: oedipus_lex version #{OedipusLex::VERSION}.",
           "#++",
           "",
           "",
           "module X"]

    assert_equal exp, ruby.lines.map(&:chomp).first(9)
  end

  def test_read_non_existent_file
    rex = OedipusLex.new

    assert_raises Errno::ENOENT do
      rex.parse_file 'non_existent_file'
    end
  end

  def test_scanner_nests_classes
    src = <<-'REX'
      module Foo
      class Baz::Calculator < Bar
      rule
        /\d+/       { [:number, text.to_i] }
        /\s+/       { [:S, text] }
      end
      end
    REX

    ruby = generate_lexer src

    assert_match 'Baz::Calculator < Bar', ruby
  end

  def test_scanner_inherits
    source = generate_lexer <<-'REX'
      class Calculator < Bar
      rule
        /\d+/       { [:number, text.to_i] }
        /\s+/       { [:S, text] }
      end
    REX

    assert_match 'Calculator < Bar', source
  end

  def test_scanner_inherits_many_levels
    source = generate_lexer <<-'REX'
      class Calculator < Foo::Bar
      rule
        /\d+/       { [:number, text.to_i] }
        /\s+/       { [:S, text] }
      end
    REX

    assert_match 'Calculator < Foo::Bar', source
  end

  def test_parses_macros_with_escapes
    source = generate_lexer %q{
      class Foo
      macro
        W  /[\ \t]+/
      rule
        /#{W}/  { [:SPACE, text] }
      end
    }

    assert_match 'ss.scan(/#{W}/)', source
  end

  def test_parses_regexp_with_interpolation_o
    source = generate_lexer %q{
      class Foo
      rule
        /#{W}/o  { [:SPACE, text] }
      end
    }

    assert_match 'ss.scan(/#{W}/o)', source
  end

  def test_parses_regexp_with_interpolation_o_macro
    source = generate_lexer %q{
      class Foo
      macro
        W  /[\ \t]+/
      rule
        /#{X}/  { [:SPACE, text] }
        /#{W}/o  { [:X, text] }
      end
    }

    assert_match 'W = /[\ \t]+/', source
    assert_match 'ss.scan(/#{W}/o)', source
    assert_match 'ss.scan(/#{X}/)', source
  end

  def test_parses_empty_regexp
    source = generate_lexer %q{
      class Foo
      rule
              /\w+/ { @state = :ARG; emit :tFUNCTION_CALL }
        :ARG  /\(/  { @state = nil; emit :tARG_LIST_BEGIN }
        :ARG  //    { @state = nil }
      end
    }

    assert_match 'ss.skip(//)', source
  end

  def test_changing_state_during_lexing
    src = <<-'REX'
      class Calculator
      rule
             /a/       { self.state = :B  ; [:A, text] }
        :B   /b/       { self.state = nil ; [:B, text] }
      end
    REX

    txt = "aba"
    exp = [[:A, 'a'], [:B, 'b'], [:A, 'a']]

    assert_lexer src, txt, exp

    txt = "aa"

    assert_lexer_error src, txt, "can not match (:B) at <input>: 'a'"
  end

  def test_error_undefined_state
    src = <<-'REX'
      class Calculator
      rule
             /a/       { self.state = :C  ; [:A, text] }
        :B   /b/       { self.state = nil ; [:B, text] }
      end
    REX

    txt = "aa"

    assert_lexer_error src, txt, "undefined state at <input>: 'C'"
  end

  def test_error_bad_token
    src = <<-'REX'
      class Calculator
      rule
             /a/       { self.state = :B  ; :A }
        :B   /b/       { self.state = nil ; [:B, text] }
      end
    REX

    txt = "aa"

    assert_token_error src, txt, "bad lexical result at <input>: :A"
  end

  def test_error_bad_token_size
    src = <<-'REX'
      class Calculator
      rule
             /a/       { self.state = :B  ; [:A] }
        :B   /b/       { self.state = nil ; [:B, text] }
      end
    REX

    txt = "aa"

    assert_token_error src, txt, "bad lexical result at <input>: [:A]"
  end

  def test_incrementing_lineno_on_nil_token
    src = <<-'REX'
      class Calculator
      option
             lineno
      rule
             /\n/
             /a/       { [:A, lineno] }
      end
    REX

    txt = "\n\na"
    exp = [[:A, 3]]

    assert_lexer src, txt, exp
  end

  def assert_location exp, option = {}
    self.option = option

    src = "class Calculator\nrule\n  /\\d+/ { [:number, text.to_i] }\nend\n"

    _, mod = eval_lexer src

    calc = mod::Calculator.new
    def calc.do_parse
      [next_token]
    end

    calc.filename = option[:filename] if option[:filename]
    calc.parse "42"

    assert_equal exp, calc.location
  end

  def test_location
    t = true

    assert_location "<input>"
    assert_location "<input>:1",   :lineno => t
    assert_location "<input>:?:0", :column => t
    assert_location "<input>:1:0", :lineno => t, :column => t

    assert_location "blah",     :filename => "blah"
    assert_location "blah:1",   :filename => "blah", :lineno => t
    assert_location "blah:?:0", :filename => "blah", :column => t
    assert_location "blah:1:0", :filename => "blah", :lineno => t, :column => t
  end
end
