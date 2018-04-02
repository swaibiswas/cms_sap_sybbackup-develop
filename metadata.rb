name                 'cms_sap_sybbackup'
maintainer           'IBM'
maintainer_email     'bharati@us.ibm.com'
license              'Proprietary - All Rights Reserved'
description          'Enables backup on sybase sap vms'
long_description     'Installs/Configures cms_sap_sybbackup'
version              '0.1.0'
chef_version         '>= 12.1' if respond_to?(:chef_version)

# The `issues_url` points to the location where issues for this cookbook are
# tracked.  A `View Issues` link will be displayed on this cookbook's page when
# uploaded to a Supermarket.
#
issues_url 'https://github.ibm.com/cms-infra-cookbooks/cms_sap_sybbackup/issues'

# The `source_url` points to the development repository for this cookbook.  A
# `View Source` link will be displayed on this cookbook's page when uploaded to
# a Supermarket.
#
source_url 'https://github.ibm.com/cms-infra-cookbooks/cms_sap_sybbackup'

supports 'redhat', '>= 6.5'
