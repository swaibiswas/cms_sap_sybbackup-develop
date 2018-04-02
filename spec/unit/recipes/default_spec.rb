#
# Cookbook:: cms_sap_sybbackup
# Spec:: default
#
# Copyright 2018 IBM Corporation, All Rights Reserved

require 'spec_helper'

describe 'cms_sap_sybbackup::default' do
  test_platforms do |platform, version|
    context "#{platform} #{version}: when all attributes are default" do
      let(:chef_run) do
        # For a complete list of available platforms and versions see:
        # https://github.com/chefspec/fauxhai/blob/master/PLATFORMS.md
        runner = ChefSpec::ServerRunner.new(platform: platform, version: version)
        runner.converge(described_recipe)
      end

      it 'converges successfully' do
        expect { chef_run }.to_not raise_error
      end
    end
  end
end
