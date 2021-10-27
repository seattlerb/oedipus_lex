require "stringio"
require 'strscan'
require "erb"
require "oedipus_lex.rex"

##
# Oedipus Lex is a lexer generator in the same family as Rexical and
# Rex. Oedipus Lex is my independent lexer fork of Rexical. Rexical
# was in turn a fork of Rex. We've been unable to contact the author
# of rex in order to take it over, fix it up, extend it, and relicense
# it to MIT. So, Oedipus was written clean-room in order to bypass
# licensing constraints (and because bootstrapping is fun).
#
# Oedipus brings a lot of extras to the table and at this point is
# only historically related to rexical. The syntax has changed enough
# that any rexical lexer will have to be tweaked to work inside of
# oedipus. At the very least, you need to add slashes to all your
# regexps.
#
# Oedipus, like rexical, is based primarily on generating code much
# like you would a hand-written lexer. It is _not_ a table or hash
# driven lexer. It uses StrScanner within a multi-level case
# statement. As such, Oedipus matches on the _first_ match, not the
# longest (like lex and its ilk).
#
# This documentation is not meant to bypass any prerequisite knowledge
# on lexing or parsing. If you'd like to study the subject in further
# detail, please try [TIN321] or the [LLVM Tutorial] or some other
# good resource for CS learning. Books... books are good. I like
# books.

class OedipusLex
  VERSION = "2.6.0" # :nodoc:

  ##
  # The class name to generate.

  attr_accessor :class_name

  ##
  # An array of header lines to have before the lexer class.

  attr_accessor :header

  ##
  # An array of lines to have after the lexer class.

  attr_accessor :ends

  ##
  # An array of lines to have inside (but at the bottom of) the lexer
  # class.

  attr_accessor :inners

  ##
  # An array of name/regexp pairs to generate constants inside the
  # lexer class.

  attr_accessor :macros

  ##
  # A hash of options for the code generator. See README.rdoc for
  # supported options.

  attr_accessor :option

  ##
  # The rules for the lexer.

  attr_accessor :rules

  ##
  # An array of lines of code to generate into the top of the lexer
  # (next_token) loop.

  attr_accessor :starts

  ##
  # An array of all the groups within the lexer rules.

  attr_accessor :group

  DEFAULTS = { # :nodoc:
    :debug    => false,
    :do_parse => false,
    :lineno   => false,
    :column   => false,
    :stub     => false,
  }

  ##
  # A Rule represents the main component of Oedipus Lex. These are the
  # things that "get stuff done" at the lexical level. They consist of:
  #
  # + an optional required start state symbol or predicate method name
  # + a regexp to match on
  # + an optional action method or block

  class Rule < Struct.new :start_state, :regexp, :action
    ##
    # What group this rule is in, if any.

    attr_accessor :group

    alias :group? :group # :nodoc:

    ##
    # A simple constructor

    def self.[] start, regexp, action
      new start, regexp.inspect, action
    end

    def initialize start_state, regexp, action # :nodoc:
      super
      self.group = nil
    end

    undef_method :to_a

    ##
    # Generate equivalent ruby code for the rule.

    def to_ruby state, predicates, exclusive
      return unless group? or
        start_state == state or
        (state.nil? and predicates.include? start_state)

      uses_text = false

      body =
        case action
        when nil, false then
          "  # do nothing"
        when /^\{/ then
          uses_text = action =~ /\btext\b/
          "  action #{action}"
        when /^:/, "nil" then
          "  [:state, #{action}]"
        else # plain method name
          uses_text = true
          "  #{action} text"
        end

      check = uses_text ? "text = ss.scan(#{regexp})" : "ss.skip(#{regexp})"

      cond = if exclusive or not start_state then
               check
             elsif /^:/.match?(start_state) then
               "(state == #{start_state}) && (#{check})"
             else # predicate method
               "#{start_state} && (#{check})"
             end

      ["when #{cond} then", body]
    end

    def pretty_print pp # :nodoc:
      pp.text "Rule"
      pp.group 2, "[", "]" do
        pp.pp start_state
        pp.text ", "
        pp.text regexp
        pp.text ", "
        pp.send(action ? :text : :pp, action)
      end
    end
  end

  ##
  # A group allows you to group up multiple rules under a single
  # regular prefix expression, allowing optimized code to be generated
  # that skips over all actions if the prefix isn't matched.

  class Group < Struct.new :regex, :rules
    alias :start_state :regex

    ##
    # A convenience method to create a new group with a +start+ and
    # given +subrules+.

    def self.[] start, *subrules
      r = new start.inspect
      r.rules.concat subrules
      r
    end

    def initialize start # :nodoc:
      super(start, [])
    end

    ##
    # Add a rule to this group.

    def << rule
      rules << rule
      nil
    end

    def to_ruby state, predicates, exclusive # :nodoc:
      [
       "when ss.match?(#{regex}) then",
       "  case",
       rules.map { |subrule|
         s = subrule.to_ruby(state, predicates, exclusive)
         s && s.join("\n").gsub(/^/, "  ")
       }.compact,
       "  end # group #{regex}"
      ]
    end

    def pretty_print pp # :nodoc:
      pp.text "Group"
      pp.group 2, "[", "]" do
        pp.seplist([regex] + rules, lambda { pp.comma_breakable }, :each) { |v|
          pp.send(String === v ? :text : :pp, v)
        }
      end
    end
  end

  ##
  # A convenience method to create a new lexer with a +name+ and given
  # +rules+.

  def self.[](name, *rules)
    r = new
    r.class_name = name
    r.rules.concat rules
    r
  end

  def initialize opts = {} # :nodoc:
    self.option     = DEFAULTS.merge opts
    self.class_name = nil

    self.header  = []
    self.ends    = []
    self.inners  = []
    self.macros  = []
    self.rules   = []
    self.starts  = []
    self.group   = nil
  end

  def == o # :nodoc:
    (o.class      == self.class      and
     o.class_name == self.class_name and
     o.header     == self.header     and
     o.ends       == self.ends       and
     o.inners     == self.inners     and
     o.macros     == self.macros     and
     o.rules      == self.rules      and
     o.starts     == self.starts)
  end

  def pretty_print pp # :nodoc:
    commas = lambda { pp.comma_breakable }

    pp.text "Lexer"
    pp.group 2, "[", "]" do
      pp.seplist([class_name] + rules, commas, :each) { |v| pp.pp v }
    end
  end

  ##
  # Process a +class+ lexeme.

  def lex_class prefix, name
    header.concat prefix.split(/\n/)
    self.class_name = name
  end

  ##
  # Process a +comment+ lexeme.

  def lex_comment line
    # do nothing
  end

  ##
  # Process an +end+ lexeme.

  def lex_end line
    ends << line
  end

  ##
  # Process an +inner+ lexeme.

  def lex_inner line
    inners << line
  end

  ##
  # Process a +start+ lexeme.

  def lex_start line
    starts << line.strip
  end

  ##
  # Process a +macro+ lexeme.

  def lex_macro name, value
    macros << [name, value]
  end

  ##
  # Process an +option+ lexeme.

  def lex_option option
    self.option[option.to_sym] = true
  end

  ##
  # Process a +X+ lexeme.

  def lex_rule start_state, regexp, action = nil
    rules << Rule.new(start_state, regexp, action)
  end

  ##
  # Process a +group head+ lexeme.

  def lex_grouphead re
    end_group if group
    self.state = :group
    self.group = Group.new re
  end

  ##
  # Process a +group+ lexeme.

  def lex_group start_state, regexp, action = nil
    rule = Rule.new(start_state, regexp, action)
    rule.group = group
    self.group << rule
  end

  ##
  # End a group.

  def end_group
    rules << group
    self.group = nil
    self.state = :rule
  end

  ##
  # Process the end of a +group+ lexeme.

  def lex_groupend start_state, regexp, action = nil
    end_group
    lex_rule start_state, regexp, action
  end

  ##
  # Process a +state+ lexeme.

  def lex_state _new_state
    end_group if group
    # do nothing -- lexer switches state for us
  end

  ##
  # Generate the lexer.

  def generate
    filter = lambda { |r| Rule === r && r.start_state || nil }
    _mystates = rules.map(&filter).flatten.compact.uniq
    exclusives, inclusives = _mystates.partition { |s| s =~ /^:[A-Z]/ }

    # NOTE: doubling up assignment to remove unused var warnings in
    # ERB binding.

    all_states =
      all_states = [[nil, *inclusives],          # nil+incls # eg [[nil, :a],
                    *exclusives.map { |s| [s] }] # [excls]   #     [:A], [:B]]

    encoding = header.shift if /encoding:/.match?(header.first)
    encoding ||= "# encoding: UTF-8"

    erb = if RUBY_VERSION >= "2.6.0" then
            ERB.new(TEMPLATE, trim_mode:"%")
          else
            ERB.new(TEMPLATE, nil, "%")
          end

    erb.result binding
  end

  # :stopdoc:

  TEMPLATE = <<-'REX'.gsub(/^ {6}/, '')
      # frozen_string_literal: true
      <%= encoding %>
      #--
      # This file is automatically generated. Do not modify it.
      # Generated by: oedipus_lex version <%= VERSION %>.
% if filename then
      # Source: <%= filename %>
% end
      #++

% unless header.empty? then
%   header.each do |s|
      <%= s %>
%   end

% end

      ##
      # The generated lexer <%= class_name %>

      class <%= class_name %>
        require 'strscan'

% unless macros.empty? then
        # :stopdoc:
%   max = macros.map { |(k,_)| k.size }.max
%   macros.each do |(k,v)|
        <%= "%-#{max}s = %s" % [k, v] %>
%   end
        # :startdoc:
% end
        # :stopdoc:
        class LexerError < StandardError ; end
        class ScanError < LexerError ; end
        # :startdoc:

% if option[:lineno] then
        ##
        # The current line number.

        attr_accessor :lineno
% end
        ##
        # The file name / path

        attr_accessor :filename

        ##
        # The StringScanner for this lexer.

        attr_accessor :ss

        ##
        # The current lexical state.

        attr_accessor :state

        alias :match :ss

        ##
        # The match groups for the current scan.

        def matches
          m = (1..9).map { |i| ss[i] }
          m.pop until m[-1] or m.empty?
          m
        end

        ##
        # Yields on the current action.

        def action
          yield
        end

% if option[:column] then
        ##
        # The previous position. Only available if the :column option is on.

        attr_accessor :old_pos

        ##
        # The position of the start of the current line. Only available if the
        # :column option is on.

        attr_accessor :start_of_current_line_pos

        ##
        # The current column, starting at 0. Only available if the
        # :column option is on.
        def column
          old_pos - start_of_current_line_pos
        end

% end
% if option[:do_parse] then
        ##
        # Parse the file by getting all tokens and calling lex_+type+ on them.

        def do_parse
          while token = next_token do
            type, *vals = token

            send "lex_#{type}", *vals
          end
        end

% end

        ##
        # The current scanner class. Must be overridden in subclasses.

        def scanner_class
          StringScanner
        end unless instance_methods(false).map(&:to_s).include?("scanner_class")

        ##
        # Parse the given string.

        def parse str
          self.ss     = scanner_class.new str
% if option[:lineno] then
          self.lineno = 1
% end
% if option[:column] then
          self.start_of_current_line_pos = 0
% end
          self.state  ||= nil

          do_parse
        end

        ##
        # Read in and parse the file at +path+.

        def parse_file path
          self.filename = path
          open path do |f|
            parse f.read
          end
        end

        ##
        # The current location in the parse.

        def location
          [
            (filename || "<input>"),
% if option[:lineno] then
            lineno,
% elsif option[:column] then
            "?",
% end
% if option[:column] then
            column,
% end
          ].compact.join(":")
        end

        ##
        # Lex the next token.

        def next_token
% starts.each do |s|
          <%= s %>
% end

          token = nil

          until ss.eos? or token do
% if option[:lineno] then
            if ss.check(/\n/) then
              self.lineno += 1
% if option[:column] then
              # line starts 1 position after the newline
              self.start_of_current_line_pos = ss.pos + 1
% end
            end
% end
% if option[:column] then
            self.old_pos = ss.pos
% end
            token =
              case state
% all_states.each do |the_states|
%   exclusive = the_states.first != nil
%   the_states, predicates = the_states.partition { |s| s.nil? or s.start_with? ":" }
              when <%= the_states.map { |s| s || "nil" }.join ", " %> then
                case
%   the_states.each do |state|
%     lines = rules.map { |r| r.to_ruby state, predicates, exclusive }.compact
<%= lines.join("\n").gsub(/^/, " " * 10) %>
%   end # the_states.each
                else
                  text = ss.string[ss.pos .. -1]
                  raise ScanError, "can not match (#{state.inspect}) at #{location}: '#{text}'"
                end
% end # all_states
              else
                raise ScanError, "undefined state at #{location}: '#{state}'"
              end # token = case state

            next unless token # allow functions to trigger redo w/ nil
          end # while

          raise LexerError, "bad lexical result at #{location}: #{token.inspect}" unless
            token.nil? || (Array === token && token.size >= 2)

          # auto-switch state
          self.state = token.last if token && token.first == :state

% if option[:debug] then
          p [state, token]
% end
          token
        end # def next_token
% inners.each do |s|
        <%= s %>
% end
      end # class
% unless ends.empty? then

%   ends.each do |s|
        <%= s %>
%   end
% end
% if option[:stub] then

      if __FILE__ == $0
        ARGV.each do |path|
          rex = <%= class_name %>.new

          def rex.do_parse
            while token = self.next_token
              p token
            end
          end

          begin
            rex.parse_file path
          rescue
            lineno = rex.respond_to?(:lineno) ? rex.lineno : -1
            $stderr.printf "%s:%d:%s\n", rex.filename, lineno, $!.message
            exit 1
          end
        end
      end
% end
  REX

  # :startdoc:
end

if $0 == __FILE__ then
  ARGV.each do |path|
    rex = OedipusLex.new

    rex.parse_file path
    puts rex.generate
  end
end
