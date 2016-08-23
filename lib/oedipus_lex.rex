class OedipusLex

option

  do_parse
  lineno

macro
  ST    /(?:(:\S+|\w+\??))/
  RE    /(\/(?:\\.|[^\/])+\/[ion]?)/
  ACT   /(\{.*|:?\w+)/

rule
# [state]       /pattern/[flags]        [actions]
  # nil state applies to all states, so we use this to switch lexing modes

                /options?.*/            :option
                /inner.*/               :inner
                /macros?.*/             :macro
                /rules?.*/              :rule
                /start.*/               :start
                /end/                   :END

                /\A((?:.|\n)*)class ([\w:]+.*)/ { [:class, *matches] }

                /\n+/                   # do nothing
                /\s*(\#.*)/             { [:comment, text] }

  :option       /\s+/                   # do nothing
  :option       /stub/i                 { [:option, text] }
  :option       /debug/i                { [:option, text] }
  :option       /do_parse/i             { [:option, text] }
  :option       /lineno/i               { [:option, text] }
  :option       /column/i               { [:option, text] }

  :inner        /.*/                    { [:inner, text] }

  :start        /.*/                    { [:start, text] }

  :macro        /\s+(\w+)\s+#{RE}/o     { [:macro, *matches] }

  :rule         /\s*#{ST}?[\ \t]*#{RE}[\ \t]*#{ACT}?/o      { [:rule, *matches] }
  :rule         /\s*:[\ \t]*#{RE}/o                         { [:grouphead, *matches] }
  :group        /\s*:[\ \t]*#{RE}/o                         { [:grouphead, *matches] }
  :group        /\s*\|\s*#{ST}?[\ \t]*#{RE}[\ \t]*#{ACT}?/o { [:group, *matches] }
  :group        /\s*#{ST}?[\ \t]*#{RE}[\ \t]*#{ACT}?/o      { [:groupend, *matches] }

  :END          /\n+/                   # do nothing
  :END          /.*/                    { [:end, text] }
end
