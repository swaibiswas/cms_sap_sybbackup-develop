#
# Cookbook:: cms_sap_bkp
# Recipe:: tsm_client_config
# This recipe configures tsm client db2 nodes for SAP customer vm
#
# Copyright:: 2018, The Authors, All Rights Reserved.

# Get dbname
dbname_cmd = Mixlib::ShellOut.new("ls -ld /sybase/*/sapdata1 | awk '{print $3,$4,$9}'")
dbname_cmd.run_command
sybsid, sybgrp, sybdir = dbname_cmd.stdout.split()
dbname = sybdir.split('/')[2]
puts 'Dbname is ' + dbname

## Take backup of dsm.sys file before creating new one.
puts 'tsm_client_home is ' + node['tsm_client_home']
dsmsysfile = node['tsm_client_home'] + 'dsm.sys'
dsmoptfile = node['tsm_client_home'] + 'dsm.opt'

require 'fileutils'
# Errorneous condition if dsm.sys and dsm.opt is not present.
# TSM BA Client must be configured before this recipe is invoked.
raise "The Required #{dsmsysfile} file not found. " unless File.exist?(dsmsysfile)
FileUtils.copy_file(dsmsysfile, dsmsysfile + '.old')

raise "The Required #{dsmoptfile} file not found. " unless File.exist?(dsmoptfile)
FileUtils.copy_file(dsmoptfile, dsmoptfile + '.old')

## Extract details from dsm.opt file to be used later in sybase stanzas
# Extract servername from dsm.opt file
fsserver = Common::Helper.getparamvalue('servername', dsmoptfile)
puts 'The TCPIP stanza servername is ' + fsserver

# Extract tsm server address and port from the dsm.sys file
tsmserver = Common::Helper.getdsmsysvalue(fsserver, dsmsysfile, 'tcpserveraddress')
node.default['tsm_server'] = tsmserver
puts 'The tsm base client is registered with ' + tsmserver

tsmport = Common::Helper.getdsmsysvalue(fsserver, dsmsysfile, 'tcpport')
puts 'TSM Server port is ' + tsmport

# Form Sybase and Sybaselog nodenames from FS nodename in dsm.sys.
nodename = Common::Helper.getdsmsysvalue(fsserver, dsmsysfile, 'nodename')

# TSM Node names are case sensitive, commands dont return output if nodename is given in smaller case. Thus upcase all node names.
nodename = nodename.upcase
nodenamesyb = nodename.gsub('_FIL', '_SYB')
nodenamesyblog = nodename.gsub('_FIL', '_SYBLOG')

puts 'The node names are: '
puts nodename
puts nodenamesyb
puts nodenamesyblog

# Find customer name from the node name
customer = nodename.split('_').first
puts 'Customer: ' + customer

# Create a temporary file to add Sybase stanzas.
dsmsyssyb = dsmsysfile + '.tmp'
template dsmsyssyb do
  source 'dsm_syb.sys.erb'
  mode   '0664'
  variables(FSNAME:            fsserver,
            SYBFULL_NODENAME:  nodenamesyb,
            SYBINC_NODENAME:   nodenamesyblog,
            TSMSERVER:         tsmserver,
            TCPPORT:           tsmport)
  action :create
end

# Append the Sybase stanzas to the dsm.sys file
# Attribute "SYBFULL_SERVERNAME" should be defined as tsm-syb
ruby_block 'verify_if_SYBASE_stanzas_are_to_be_added' do
  block do
    # Append Sybase stanzas only if they already don't exist.
    ispresent = Common::Helper.isstanzapresent(node['SYBFULL_SERVERNAME'], dsmsysfile)
    if ispresent != true
      puts 'Appending SYBASE stanzas in dsm.sys file'
      to_append = File.read(dsmsyssyb)
      File.open(dsmsysfile, 'a') do |handle|
        handle.puts to_append
      end
      puts 'Updated dsm.sys is ' + dsmsysfile
    end
  end
end

## Create dsm_syb.opt file /opt/tivoli/tsm/client/ba/bin/dsm_syb.opt
dsmsyboptfile = node['tsm_client_home'] + 'dsm_syb.opt'
puts 'dsm_syb.opt is ' + dsmsyboptfile

template dsmsyboptfile do
  source 'dsm_syb.opt.erb'
  mode '0664'
  variables(SYBFULL_SERVERNAME: node['SYBFULL_SERVERNAME'])
end

## Create dsm_syblog.opt file /opt/tivoli/tsm/client/ba/bin/dsm_syblog.opt
# Attribute "SYBINC_SERVERNAME" should be defined as syb-log"
dsmsyblogoptfile = node['tsm_client_home'] + 'dsm_syblog.opt'

template dsmsyblogoptfile do
  source 'dsm_syblog.opt.erb'
  mode '0664'
  variables(SYBINC_SERVERNAME: node['SYBINC_SERVERNAME'])
end

## Update rc.dsmcad and Create rc.dsmcad_syb, rc.dsmcad_syblog with required entries

# Source file '/opt/tivoli/tsm/client/ba/bin/rc.dsmcad'
file_rcdsmcad = '/opt/tivoli/tsm/client/ba/bin/rc.dsmcad'

# The TSM BA Client must be configured before this recipe is invoked.
raise "ERROR: The \"#{file_rcdsmcad}\" is missing; \
TSM BA Client not configured correctly. " unless File.exist?(file_rcdsmcad)

puts "Taking backup of the \"#{file_rcdsmcad}\" file."
FileUtils.copy_file(file_rcdsmcad, file_rcdsmcad + '.old')

# Target files to update/create rc.dsmcad, rc.dsmcad_syb, rc.dsmcad_syblog
file_rcdsmcadtmp = file_rcdsmcad + '.tmp'
file_rcdsmcadsyb = file_rcdsmcad + '_syb'
file_rcdsmcadsyblog = file_rcdsmcad + '_syblog'

explang = 'export LANG=' # 'export LANG=\"en_US\"'
exprlc_all = 'export LC_ALL=' # 'export LC_ALL=\"en_US\"'
dsmcaddir = 'DSMCAD_DIR=' # 'DSMCAD_DIR=/opt/tivoli/tsm/client/ba/bin'

sybopt = 'OPTFILE=/opt/tivoli/tsm/client/ba/bin/dsm_syb.opt'
syblogopt = 'OPTFILE=/opt/tivoli/tsm/client/ba/bin/dsm_syblog.opt'

daemon_rcdsmcad = "daemon \$DSMCAD_BIN -optfile=\$OPTFILE"
startproc_rcdsmcad = "startproc \$DSMCAD_BIN -optfile=\$OPTFILE"
daemonrcexpr = 'daemon'
startprocexpr = 'startproc'

# Skip if the rc.dsmcad_syb files exists; Note rc.dsmcad_syb & rc.dsmcad_syblog files are created at same time
unless File.exist?(file_rcdsmcadsyb)
  flag = false
  fr = File.open(file_rcdsmcad, 'r')
  f1 = File.open(file_rcdsmcadtmp, 'w')
  f2 = File.open(file_rcdsmcadsyb, 'w')
  f3 = File.open(file_rcdsmcadsyblog, 'w')

  fr.each_line do |line|
    if flag == false
      # Add OPTFILE entry for syb & syblog if 'export LANG' found
      if line.strip =~ /^#{explang}/i
        f2.puts ''
        f2.puts sybopt
        f3.puts ''
        f3.puts syblogopt
        flag = true
      elsif line.strip =~ /^#{dsmcaddir}/i
        # Add export LANG, LC_ALL , OPTFILE entries before DSMCAD_DIR if export LANG not found
        f1.puts explang + '"en_US"'
        f1.puts exprlc_all + '"en_US"'
        f2.puts explang + '"en_US"'
        f2.puts exprlc_all + '"en_US"'
        f2.puts ''
        f2.puts sybopt
        f3.puts explang + '"en_US"'
        f3.puts exprlc_all + '"en_US"'
        f3.puts ''
        f3.puts syblogopt
        flag = true
      end # End of if-else-if line.strip expr match & add
      # Add existing lines to all 3 files
      f1.puts line
      f2.puts line
      f3.puts line
    else # else for if flag true
      f1.puts line
      # Add daemon OPTFILE for rc.dsmcad_syb & rc.dsmcad_syblog
      if line.strip =~ /^#{daemonrcexpr}/i
        f2.puts '      ' + daemon_rcdsmcad
        f3.puts '      ' + daemon_rcdsmcad
      # Add 'startproc $DSMCAD_BIN' OPTFILE for rc.dsmcad_syb & rc.dsmcad_syblog
      elsif line.strip =~ /^#{startprocexpr}/i
        f2.puts '      ' + startproc_rcdsmcad
        f3.puts '      ' + startproc_rcdsmcad
      else
        f2.puts line
        f3.puts line
      end # End of if-else-if line.strip expr match & modify
    end # End of if-else-end flag true
  end ## End of loop
  fr.close
  f1.close
  f2.close
  f3.close

  # update rc.dsmcad file using rc.dsmcad.tmp
  FileUtils.copy_file(file_rcdsmcadtmp, file_rcdsmcad)
  puts 'Modified the rc.dsmcad file.'
end

# Change permissions of the rc.dsmcad , rc.dsmcad_syb & rc.dsmcad_syblog files
FileUtils.chmod 0755, file_rcdsmcad
FileUtils.chmod 0755, file_rcdsmcadsyb
FileUtils.chmod 0755, file_rcdsmcadsyblog

## create/update "/var/tsm" directory, if missing
vartsmdir = '/var/tsm'
directory vartsmdir do
  owner 'root'
  group 'root'
  mode '0777'
  action :create
end

## Create log/error file: '/opt/tivoli/tsm/client/ba/bin/dsm*.log'
# schedlogname & errorlogname for both Sybase backup and sybase log backup
vartsmdir           = '/var/tsm/'
dsmsched            = node['tsm_client_home'] + 'dsmsched.log'
dsmerror            = node['tsm_client_home'] + 'dsmerror.log'
dsmsched_syb        = vartsmdir + 'dsmsched_syb.log'
dsmserror_syb       = vartsmdir + 'dsmerror_syb.log'
dsmsched_syblog     = node['tsm_client_home'] + 'dsmsched_log.log'
dsmerror_syblog     = node['tsm_client_home'] + 'dsmerror_log.log'

puts 'dsmsched_syb.log is ' + dsmsched_syb
puts 'dsmerror_syb.log is ' + dsmserror_syb

# Touch the the error and sched logs
filenames = [dsmsched, dsmerror, dsmsched_syb, dsmserror_syb, dsmsched_syblog, dsmerror_syblog]

filenames.each do |fname|
  puts 'log file name is ' + fname
  file fname do
    mode '0666'	# -rw_rw_rw_
    action :create_if_missing
  end
end

# Begin registration of Sybase nodes and association of nodes using dsm admin client.
cont = "#{customer};#{node['dpe_email']};#{node['sr#']}"
cmd = "dsmadmc -DATAONLY=YES -id=#{node['tsm_id']} -pa=#{node['tsm_pwd']}"

# Loop through Sybase nodes with their respective domain, to register them on TSM,
[[nodenamesyb, 'full'], [nodenamesyblog, 'incr']].each do |nname, ntype|
  # Defines the queries that will be executed.
  register_query = format(node['SYBASE']['query']["register_#{ntype}"], nodename: nname, password: node['SYBASE']['tsm_node_password'], dom: node['SYBASE']["tsm_#{ntype}_domain"], cont: cont)
  # puts '## cmd is: ' + cmd
  # puts '## register_query is: ' + register_query

  # Registers the node if the node is not already registered
  execute "register_#{nname}" do
    cwd          node['tsm_client_home']
    sensitive    true
    command      "#{cmd} \"#{register_query}\""
    not_if       "#{cmd} \"q node #{nname}\""
  end
end

# To find the System's LONG_BIT 64 bit
# bit=`getconf LONG_BIT`
# puts "The vm is " + bit.strip + " bit"
bit_cmd = Mixlib::ShellOut.new('getconf LONG_BIT')
bit_cmd.run_command
bit = bit_cmd.stdout.strip
tsm_api_home = node['tsm_api_home'] + bit.strip + '/'
puts '## => tsm_api_home is ' + tsm_api_home

## Add links to the TSM API for
# '/opt/tivoli/tsm/client/ba/bin/dsm_syb.opt' as '/opt/tivoli/tsm/client/api/bin64/dsm.opt'
# '/opt/tivoli/tsm/client/ba/bin/dsm.sys' as '/opt/tivoli/tsm/client/api/bin64/dsm.sys'
link "#{tsm_api_home}dsm.opt" do
  to "#{node['tsm_client_home']}dsm_syb.opt"
  link_type:symbolic
  action:create
end

link "#{tsm_api_home}dsm.sys" do
  to "#{node['tsm_client_home']}dsm.sys"
  link_type:symbolic
  action:create
end

# Set the tsm node password so that no password prompts are asked.
dsmservers = [fsserver, node['SYBFULL_SERVERNAME'], node['SYBINC_SERVERNAME']]
dsmservers.each do |server|
  execute "set_password_locally_#{server}" do
    cwd          node['tsm_client_home']
    sensitive    true
    command      "dsmc set password #{node['SYBASE']['tsm_node_password']} #{node['SYBASE']['tsm_node_password']} -se=#{server}"
    not_if       "echo quit | dsmc -se=#{server}"
    # As part of #1656, we will not take backup in the config flow. CAM will invoke a separate script to take backup.
    # notifies :run, "ruby_block[initiate_backup_#{server}]", :immediate
  end

  # Initiate a manual backup for the first time. This will be called only once when the passwords are set.
  # Ideally this block should run only once, but cannot be ensured to be idempotent. Expectation is tsm node password does not change for a long time.
  ruby_block "initiate_backup_#{server}" do
    block do
      require 'open3'
      puts 'If the backup is initiated for the first time, it may take very long for this to complete.'
      stdout, stderr, status = Open3.capture3("dsmc -se=#{server}", stdin_data: 'i')
      puts stdout
      puts stderr
      puts status
    end
    action :nothing
  end
end

# Required for sybtsmmpasswd script to execute successfully
file '/etc/profile.d/sybdsmivars.sh' do
  content "export DSMI_LIB=/opt/tivoli/tsm/client/api/bin64/libApiTSM64.so
export DSMI_DIR=/opt/tivoli/tsm/client/api/bin64
export DSMI_LOG=/var/tsm
export DSMI_CONFIG=/opt/tivoli/tsm/client/api/bin64/dsm.opt
"
  mode '0755'
  action :create_if_missing
end

# Required for Sybase scripts to run, else it fails with DSMI_DIR not set error.
file '/etc/profile.d/sybdsmivars.csh' do
  content "setenv DSMI_LIB /opt/tivoli/tsm/client/api/bin64/libApiTSM64.so
setenv DSMI_DIR /opt/tivoli/tsm/client/api/bin64
setenv DSMI_LOG /var/tsm
setenv DSMI_CONFIG /opt/tivoli/tsm/client/api/bin64/dsm.opt
"
  mode '0755'
  action :create_if_missing
end

# Find and execute sybtsmpasswd
# pwloc = `find / -name sybtsmpasswd -print | head -1`
# /sybase/PGR/ASE-16_0/bin/sybtsmpasswd
asename_cmd = Mixlib::ShellOut.new("ls -ld /sybase/*/ASE* | awk '{print $9}'")
asename_cmd.run_command
asename = asename_cmd.stdout.split('/')[3].strip
pwloc = "/sybase/#{dbname.upcase}/#{asename}/bin/sybtsmpasswd"
pwd = node['SYBASE']['tsm_node_password']

raise "sybtsmpasswd file could not be found at location #{pwloc} ." unless File.exist?(pwloc)
# Copy and execute sybtsmpasswd
ruby_block 'exec_sybtsmpasswd' do
  block do
    # Execute the one time password setting from sybtsmpasswd.
    result = Common::Helper.execute_sybtsmpasswd(". /etc/profile.d/sybdsmivars.sh ; #{pwloc}", pwd, pwd)
    desired_result = 'Your new password has been accepted and updated.'
    if desired_result == result
      # give permission to TSM.* files at /opt/tivoli/tsm/client/ba/bin/
      FileUtils.chmod 0775, Dir.glob('/opt/tivoli/tsm/client/ba/bin/TSM.*')
      FileUtils.chown sybsid, sybgrp, Dir.glob('/opt/tivoli/tsm/client/ba/bin/TSM.*')
      puts 'Passwords successfully updated.'
    else
      puts 'Passwords were not updated.'
      raise 'sybtsmpasswd execution one time password could not be set.'
    end
  end
end

runsidbs = '/sybase/' + dbname.upcase + '/' + asename + "/install/RUN_#{dbname.upcase}_BS"
puts 'RUN_SID_BS script is ' + runsidbs
puts 'dbname is ' + dbname
flag = false

# The TSM BA Client must be configured before this recipe is invoked.
raise "ERROR: RUN_#{dbname.upcase}_BS file is missing. This is an error" unless File.exist?(runsidbs)
puts "Taking backup of the RUN_#{dbname.upcase}_BS file."
FileUtils.copy_file(runsidbs, runsidbs + '.old')
runsidbstmp = runsidbs + '.tmp'

flag = true if Common::Helper.isexprpresent(runsidbs, 'export DSMI_')

f = File.open(runsidbs, 'r')
f1 = File.open(runsidbstmp, 'w')

f.each_line do |line|
  line = line.strip
  if line.empty?
    f1.puts line
  elsif line =~ /^#/i
    f1.puts line
  elsif line =~ /^'export DSMI_'/i
    f1.puts line
    flag = true
  elsif flag == true
    f1.puts line
  else
    f1.puts ''
    f1.puts 'export DSMI_LIB=/opt/tivoli/tsm/client/api/bin64/libApiTSM64.so'
    f1.puts 'export DSMI_DIR=/opt/tivoli/tsm/client/api/bin64'
    f1.puts 'export DSMI_LOG=/var/tsm'
    f1.puts 'export DSMI_CONFIG=/opt/tivoli/tsm/client/api/bin64/dsm.opt'
    f1.puts ''
    f1.puts line
    flag = true
  end
end
f.close
f1.close

puts "updating the file.#{runsidbs}"
FileUtils.mv(runsidbstmp, runsidbs)
FileUtils.chmod 0750, runsidbs
FileUtils.chown sybsid, sybgrp, runsidbs

# Configure Sybase
include_recipe 'cms_sap_sybbackup::syb_config'

# Link Backup script to standard location
# ln -s /backup/tsm/tsm_backup_launcher.csh /opt/tivoli/tsm/client/api/bin64/tsm_backup_launcher.sh
link '/opt/tivoli/tsm/client/api/bin64/tsm_backup_launcher.sh' do
  to '/backup/tsm/tsm_backup_launcher.csh'
  link_type :symbolic
  action :create
  only_if 'test -L /opt/tivoli/tsm/client/api/bin64/tsm_backup_launcher.sh'
end

# Start dsmcad services if not already running
bash 'startdsmcadservice' do
  cwd '/opt/tivoli/tsm/client/ba/bin'
  code <<-EOH
cp /opt/tivoli/tsm/client/ba/bin/rc.dsmcad /etc/rc.d/init.d/rc.dsmcad
cp /opt/tivoli/tsm/client/ba/bin/rc.dsmcad_syb /etc/rc.d/init.d/rc.dsmcad_syb
cp /opt/tivoli/tsm/client/ba/bin/rc.dsmcad_syblog /etc/rc.d/init.d/rc.dsmcad_syblog
chkconfig --add rc.dsmcad
chkconfig --level 345 rc.dsmcad on
chkconfig --list rc.dsmcad
chkconfig --add rc.dsmcad_syb
chkconfig --level 345 rc.dsmcad_syb on
chkconfig --list rc.dsmcad_syb
chkconfig --add rc.dsmcad_syblog
chkconfig --level 345 rc.dsmcad_syblog on
chkconfig --list rc.dsmcad_syb

service  rc.dsmcad stop
service  rc.dsmcad Start
service  rc.dsmcad_syb start
service  rc.dsmcad_syblog start
EOH
end

# Associate the node to schedules
# Loop through Sybase nodes with their respective domain, to find appr. schedule and associate them on TSM,
[[nodenamesyb, 'full'], [nodenamesyblog, 'incr']].each do |nname, ntype|
  # Defines the queries that will be executed.
  schedquery = format(node['SYBASE']['query']['schedule'], dom: node['SYBASE']["tsm_#{ntype}_domain"], schedpattern: node['SYBASE']['schedule'][ntype])
  assocquery = format(node['SYBASE']['query']['associate'], dom: node['SYBASE']["tsm_#{ntype}_domain"], schedule: '$SCHEDNAME', nodename: nname)

  # Query to check if association exists.
  existassc = format(node['SYBASE']['query']['existassoc'], dom: node['SYBASE']["tsm_#{ntype}_domain"], schedpattern: node['SYBASE']['schedule'][ntype], nodename: nname)
  # Execute for association
  execute "associate_#{nname}" do
    cwd node['tsm_client_home']
    sensitive  false
    command    "SCHEDNAME=`#{cmd} \"#{schedquery}\" | awk '{ print $1 }'`;
                   #{cmd} \"#{assocquery}\""
    not_if     "#{cmd} \"#{existassc}\""
  end
end
