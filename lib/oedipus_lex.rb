require "stringio"
require 'strscan'
require "erb"
require "oedipus_lex.rex"

class OedipusLex
  VERSION = "2.3.2"

  attr_accessor :class_name
  attr_accessor :header
  attr_accessor :ends
  attr_accessor :inners
  attr_accessor :macros
  attr_accessor :option
  attr_accessor :rules
  attr_accessor :starts
  attr_accessor :group

  DEFAULTS = {
    :debug    => false,
    :do_parse => false,
    :lineno   => false,
    :stub     => false,
  }

  class Rule < Struct.new :start_state, :regexp, :action
    attr_accessor :group
    alias :group? :group

    def self.[] start, regexp, action
      new start, regexp.inspect, action
    end

    def initialize start_state, regexp, action
      super
      self.group = nil
    end

    undef_method :to_a

    def to_ruby state, predicates, exclusive
      return unless group? or
        start_state == state or
        (state.nil? and predicates.include? start_state)

      cond =
        if exclusive or not start_state then
          "when text = ss.scan(#{regexp}) then"
        elsif start_state =~ /^:/ then
          "when (state == #{start_state}) && (text = ss.scan(#{regexp})) then"
        else
          "when #{start_state} && (text = ss.scan(#{regexp})) then"
        end

      body =
        case action
        when nil, false then
          "  # do nothing"
        when /^\{/ then
          "  action #{action}"
        when /^:/, "nil" then
          "  [:state, #{action}]"
        else
          "  #{action} text"
        end

      [cond, body]
    end

    def pretty_print pp
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

  class Group < Struct.new :regex, :rules
    alias :start_state :regex

    def self.[] start, *subrules
      r = new start.inspect
      r.rules.concat subrules
      r
    end

    def initialize start
      super(start, [])
    end

    def << rule
      rules << rule
      nil
    end

    def to_ruby state, predicates, exclusive
      [
       "when ss.check(#{regex}) then",
       "  case",
       rules.map { |subrule|
         s = subrule.to_ruby(state, predicates, exclusive)
         s && s.join("\n").gsub(/^/, "  ")
       }.compact,
       "  end # group #{regex}"
      ]
    end

    def pretty_print pp
      pp.text "Group"
      pp.group 2, "[", "]" do
        pp.seplist([regex] + rules, lambda { pp.comma_breakable }, :each) { |v|
          pp.send(String === v ? :text : :pp, v)
        }
      end
    end
  end

  def self.[](name, *rules)
    r = new
    r.class_name = name
    r.rules.concat rules
    r
  end

  def initialize opts = {}
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

  def == o
    (o.class      == self.class      and
     o.class_name == self.class_name and
     o.header     == self.header     and
     o.ends       == self.ends       and
     o.inners     == self.inners     and
     o.macros     == self.macros     and
     o.rules      == self.rules      and
     o.starts     == self.starts)
  end

  def pretty_print pp
    commas = lambda { pp.comma_breakable }

    pp.text "Lexer"
    pp.group 2, "[", "]" do
      pp.seplist([class_name] + rules, commas, :each) { |v| pp.pp v }
    end
  end

  def lex_class prefix, name
    header.concat prefix.split(/\n/)
    self.class_name = name
  end

  def lex_comment line
    # do nothing
  end

  def lex_end line
    ends << line
  end

  def lex_inner line
    inners << line
  end

  def lex_start line
    starts << line.strip
  end

  def lex_macro name, value
    macros << [name, value]
  end

  def lex_option option
    self.option[option.to_sym] = true
  end

  def lex_rule start_state, regexp, action = nil
    rules << Rule.new(start_state, regexp, action)
  end

  def lex_grouphead re
    end_group if group
    self.state = :group
    self.group = Group.new re
  end

  def lex_group start_state, regexp, action = nil
    rule = Rule.new(start_state, regexp, action)
    rule.group = group
    self.group << rule
  end

  def end_group
    rules << group
    self.group = nil
    self.state = :rule
  end

  def lex_groupend start_state, regexp, action = nil
    end_group
    lex_rule start_state, regexp, action
  end

  def lex_state new_state
    end_group if group
    # do nothing -- lexer switches state for us
  end

  def generate
    filter = lambda { |r| Rule === r && r.start_state || nil }
    _mystates = rules.map(&filter).flatten.compact.uniq
    exclusives, inclusives = _mystates.partition { |s| s =~ /^:[A-Z]/ }

    # NOTE: doubling up assignment to remove unused var warnings in
    # ERB binding.

    all_states =
      all_states = [[nil, *inclusives],          # nil+incls # eg [[nil, :a],
                    *exclusives.map { |s| [s] }] # [excls]   #     [:A], [:B]]

    encoding = header.shift if header.first =~ /encoding:/
    encoding ||= "# encoding: UTF-8"

    ERB.new(TEMPLATE, nil, "%").result binding
  end

  TEMPLATE = <<-'REX'.gsub(/^ {6}/, '')
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
      class <%= class_name %>
        require 'strscan'

% unless macros.empty? then
%   max = macros.map { |(k,_)| k.size }.max
%   macros.each do |(k,v)|
        <%= "%-#{max}s = %s" % [k, v] %>
%   end

% end
        class ScanError < StandardError ; end

        attr_accessor :lineno
        attr_accessor :filename
        attr_accessor :ss
        attr_accessor :state

        alias :match :ss

        def matches
          m = (1..9).map { |i| ss[i] }
          m.pop until m[-1] or m.empty?
          m
        end

        def action
          yield
        end

% if option[:do_parse] then
        def do_parse
          while token = next_token do
            type, *vals = token

            send "lex_#{type}", *vals
          end
        end

% end
        def scanner_class
          StringScanner
        end unless instance_methods(false).map(&:to_s).include?("scanner_class")

        def parse str
          self.ss     = scanner_class.new str
          self.lineno = 1
          self.state  ||= nil

          do_parse
        end

        def parse_file path
          self.filename = path
          open path do |f|
            parse f.read
          end
        end

        def next_token
% starts.each do |s|
          <%= s %>
% end

          token = nil

          until ss.eos? or token do
% if option[:lineno] then
            self.lineno += 1 if ss.peek(1) == "\n"
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
                  raise ScanError, "can not match (#{state.inspect}): '#{text}'"
                end
% end # all_states
              else
                raise ScanError, "undefined state: '#{state}'"
              end # token = case state

            next unless token # allow functions to trigger redo w/ nil
          end # while

          raise "bad lexical result: #{token.inspect}" unless
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
            $stderr.printf "%s:%d:%s\n", rex.filename, rex.lineno, $!.message
            exit 1
          end
        end
      end
% end
  REX
end

if $0 == __FILE__ then
  ARGV.each do |path|
    rex = OedipusLex.new

    rex.parse_file path
    puts rex.generate
  end
end
