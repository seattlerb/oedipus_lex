# -*- ruby -*-

$: << "lib"
require "oedipus_lex"

$rex_option = {}

rule ".rex.rb" => proc {|path| path.sub(/\.rb$/, "") } do |t|
  warn "Generating #{t.name} from #{t.source}"
  rex = OedipusLex.new $rex_option
  rex.parse_file t.source

  File.open t.name, "w" do |f|
    f.write rex.generate
  end
end
