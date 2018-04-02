#
# Cookbook:: cms_sap_sybbackup
# Spec:: default
#
# Copyright 2018 IBM Corporation, All Rights Reserved

require 'chefspec'
require 'chefspec/berkshelf'

# The platforms we support
# For a complete list of available platforms and versions see:
# https://github.com/chefspec/fauxhai/blob/master/PLATFORMS.md
def test_platforms
  {
    'redhat' => %w(6.8 7.3)
  }.each do |platform, versions|
    versions.each do |version|
      yield(platform, version)
    end
  end
end

ChefSpec::Coverage.start! do
  add_output do |report_output|
    File.open('coverage.json', 'w') do |f|
      f.puts(report_output[:coverage])
    end
  end
end
