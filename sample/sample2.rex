#
# sample2.rex
# lexical definition sample for rex
#
# usage
#  rex  sample2.rex  --stub
#  ruby sample2.rex.rb  sample2.bas
#

class Sample2
macro
  BLANK         /\s+/
  REMARK        /\'/              # '

rule
                /{{REMARK}}/    :REM
  :REM          /\n/            { [:state, nil] }
  :REM          /.*(?=$)/       { [:remark, text] }

                /\"[^"]*\"/     { [:string, text] }

                /{{BLANK}}/     # no action

                /INPUT/i        { [:input, text] }
                /PRINT/i        { [:print, text] }

                /\d+/           { [:digit, text.to_i] }
                /\w+/           { [:word, text] }
                /./             { [text, text] }
end
