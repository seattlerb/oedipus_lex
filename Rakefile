# -*- ruby -*-

require "rubygems"
require "hoe"

Hoe.plugin :debugging
Hoe.plugin :git
Hoe.plugin :isolate
Hoe.plugin :seattlerb

Hoe.spec "oedipus_lex" do
  developer "Ryan Davis", "ryand-ruby@zenspider.com"
  license "MIT"

  self.readme_file      = "README.rdoc"
  self.history_file     = "History.rdoc"
end

task :bootstrap do
  ruby "-Ilib lib/oedipus_lex.rb lib/oedipus_lex.rex > lib/oedipus_lex.rex.rb.new"
  system "diff -uw lib/oedipus_lex.rex.rb lib/oedipus_lex.rex.rb.new"
  sh "mv lib/oedipus_lex.rex.rb.new lib/oedipus_lex.rex.rb"
  ruby "-S rake"
end

$: << "lib"
Rake.application.rake_require "oedipus_lex"
$rex_option[:stub] = true

task :demo => Dir["sample/*.rex"].map { |s| "#{s}.rb" }.sort

task :demo => :isolate do
  Dir.chdir "sample" do
    ruby "sample.rex.rb sample.html"
    ruby "sample.rex.rb sample.xhtml"

    ruby "sample1.rex.rb sample1.c"

    ruby "sample2.rex.rb sample2.bas"

    ruby "xhtmlparser.rex.rb xhtmlparser.html"
    ruby "xhtmlparser.rex.rb xhtmlparser.xhtml"

    cmd = "#{Gem.ruby} error1.rex.rb error1.txt"
    warn cmd
    system cmd

    cmd = "#{Gem.ruby} error2.rex.rb error1.txt"
    warn cmd
    system cmd
  end
end

task :raccdemo => :isolate do
  $rex_option[:stub] = false
  $rex_option[:do_parse] = false

  rm_f "sample/calc3.rex.rb"
  t = Rake.application["sample/calc3.rex.rb"]
  t.reenable
  t.invoke

  ruby "-S racc sample/calc3.racc"

  sh "echo 1 + 2 + 3 | #{Gem.ruby} -Isample sample/calc3.tab.rb"
end

task :clean do
  rm Dir["sample/*.rb"]
end

task :debug do
  require "oedipus_lex"
  f = ENV["F"]
  rex = OedipusLex.new $rex_option
  rex.parse_file f

  puts rex.generate
end

# vim: syntax=ruby
