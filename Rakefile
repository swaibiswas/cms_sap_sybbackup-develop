require 'rake/clean'
require 'foodcritic'
require 'rubocop/rake_task'
require 'rspec/core/rake_task'
require 'kitchen/rake_tasks'

BERKSLOCK = 'Berksfile.lock'.freeze
BUILD = 'build'.freeze

CLEAN.include BUILD
CLEAN.include BERKSLOCK
CLOBBER.include BUILD
CLOBBER.include BERKSLOCK

directory BUILD

desc 'reinitialize Berkshelf'
task berks: :clean do
  sh 'chef exec berks install'
  sh 'chef exec berks update'
end

FoodCritic::Rake::LintTask.new(:foodcritic) do |t|
  t.options = {
    tags: %w(~FC001 ~FC014 ~FC019 ~FC078),
    fail_tags: %w(any)
  }
end
task :foodcritic

RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = '--fail-fast'
end
task :spec

RuboCop::RakeTask.new(:cookstyle) do |t|
  t.requires = ['cookstyle']
  t.options = %w(-E -D -c .rubocop.yml)
end
task :cookstyle

Kitchen::RakeTasks.new

desc "berks package this cookbook to #{BUILD}/"
task package: [:clean, BUILD] do
  sh "berks vendor #{BUILD}/"
  sh "berks package #{BUILD}/cookbooks.tar.gz"
  cp 'metadata.rb', "#{BUILD}/"
  cp 'README.md', "#{BUILD}/"
  cp 'CHANGELOG.md', "#{BUILD}/"
end

lint = %w(foodcritic cookstyle)
desc lint.join(' -> ')
task lint: lint

default = %w(lint spec kitchen:all)
desc default.join(' -> ')
task default: default
