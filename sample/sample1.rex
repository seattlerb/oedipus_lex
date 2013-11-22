#
# sample1.rex
# lexical definition sample for rex
#
# usage
#  rex  sample1.rex  --stub
#  ruby sample1.rex.rb  sample1.c
#

class Sample1
macro
  BLANK         /\s+/
  REM_IN        /\/\*/
  REM_OUT       /\*\//
  REM           /\/\//

rule

# [:state]  pattern  [actions]

# remark
                /{{REM_IN}}/        :REMS
  :REMS         /{{REM_OUT}}/       { [:state, nil] }
  :REMS         /.*(?={{REM_OUT}})/ { [:remark, text] }
                /{{REM}}/           :REM
  :REM          /\n/                { [:state, nil] }
  :REM          /.*(?=$)/           { [:remark, text] }

# literal
                /\"[^"]*\"/         { [:string, text]    }
                /\'[^']\'/          { [:character, text] }

# skip
                /{{BLANK}}/

# numeric
                /\d+/               { [:digit, text.to_i] }

# identifier
                /\w+/               { [:word, text] }
                /./                 { [text, text] }

end
