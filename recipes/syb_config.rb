#
# Cookbook:: cms_sap_sybbackup
# Recipe:: syb_config.rb
#
# Author:: bharati_patidar (SAP Auto & Orch Squad)
# Copyright:: 2018, The Authors, All Rights Reserved.

# Find Sybase Servername. Servername need not be only 3 chars for non-sap.
sname_cmd = Mixlib::ShellOut.new("ls -ld /sybase/*/sapdata1 | awk '{print $3,$4,$9}'")
sname_cmd.run_command
sybsid, sybgrp, sybdir = sname_cmd.stdout.split()
sname = sybdir.split('/')[2]
sname = sname.strip

# Check pre-requisites on space on filesystems.
fsystems = [['/backup', node['fs_backup_req_free_gb']], ["/sybase/#{sname}/log_archive", node['fs_logarch_req_free_gb']]]
fsystems.each do |fs, req_disk|
  raise "Required filesystem #{fs} doesn't exist" unless File.exist?(fs)
  fsize_cmd = Mixlib::ShellOut.new("df -BG #{fs}")
  fsize_cmd.run_command
  gb_disk = fsize_cmd.stdout.split[8].to_i
  raise "#{fs} is only #{gb_disk} GB while required is #{req_disk} GB " if gb_disk < req_disk
end

require 'fileutils'

# Copy source scripts/sql files from sds to /backup
FileUtils.cp_r node['sds_src_location'] + '/scripts', '/backup'
FileUtils.cp_r node['sds_src_location'] + '/tsm', '/backup'

SYB_HOME = ('/sybase/' + sname).freeze

# Adding <SID>_XP entry in interfaces file.
puts 'Adding <SID>_XP entry in interfaces file, if not already present'
xp = sname + '_XP'
is_xp_present = false

r = /(\d+)$/
nextport = 0
servername = ''

# Scan interface file to check if XP server exists. If does not, add an entry for XP
File.open "#{SYB_HOME}/interfaces" do |filename|
  # Read interfaces file line by line
  filename.each_line do |line|
    line.chomp!
    next if line.empty?
    # Check if _XP is already present. Break if so
    is_xp_present = true if line =~ /^#{xp}/i
    break if is_xp_present == true
    # Find next available port number for the XP server entry.
    next unless line =~ r  # Only if the line contains numbers.
    m = r.match line
    port = m[0].to_i       # Extract port number
    nextport = port if nextport < port
    servername = line.split()[3] if servername == '' # Get servername as well.
  end
end
# If XP server not present, add it.
if is_xp_present == false
  freeport = nextport + 1
  puts 'Appending SID_XP entry in intefaces table'
  open("#{SYB_HOME}/interfaces", 'a') do |f|
    f.puts ''
    f.puts xp.upcase
    f.puts "        master tcp ether #{servername} #{freeport}"
    f.puts "        query tcp ether #{servername} #{freeport}"
  end
end

# Update the sql scripts replacing tokens with real values.
files = [['tsm_syb_full', [['SID', sname.upcase]]], ['tsm_syb_purge', [['SID', sname.upcase]]],
         ['tsm_bkp_launcher', [['SID', sname.downcase]]], ['tsm_prg_launcher', [['SID', sname.downcase]]],
         ['dbcreate', [['SID', sname]]], ['createlogin', [['sybdba_pwd', node['creds']['sybdba']]]],
         ['sybmgmtdb', [['sybdba_pwd', node['creds']['sybdba']], ['DBNAME', sname.upcase], ['SERVERNAME', sname.upcase]]]]
files.each do |srcfile, values|
  src_file = node[srcfile]
  tgt_file = node[srcfile] + '.tmp'

  Common::Helper.replace_tokens(src_file, tgt_file, values)
  puts 'Updated ' + src_file
  FileUtils.mv tgt_file, src_file
end

# Ensure permission on script and tsm folders under backup are good.
FileUtils.chmod_R 0775, '/backup/'
FileUtils.chown_R sybsid, sybgrp, '/backup/'

# Create a tmp folder for the templates.
FileUtils.mkdir_p SYB_HOME + '/tmp'
FileUtils.chown_R sybsid, sybgrp, SYB_HOME + '/tmp'

# Execute script files based on netweaver or non-netweaver application
app_type = node['app_type']

# Super database user for all commands.
user = 'sybdba'
pwd = node['creds'][user]

# Create temporary files to execute sybase commands on sybase login
syb_files = %w(setup_xp tsm_db_full_backup db_full_bkp)
syb_files.each do |syb_file|
  tname = syb_file + '.erb'
  template "#{SYB_HOME}/tmp/#{syb_file}" do
    source tname
    mode   '0775'
    variables(XP: xp,
              DBNAME: sname,
              SYBDBA_PWD: pwd,
              SNAME: sname)
    action :create
  end
end

# Create a has of commands to be fired on the shell
cmd_hash = {}
cnt = 1

# Adds all sql commands.
script_files = %w(dbcreate createlogin sarole create_sps)
script_files.each do |sfile|
  user = node[app_type]['cmd_users'][sfile]
  pwd = node['creds'][user]
  script = node[sfile]

  script_hash = {}
  script_hash['cmd'] = "isql -U#{user} -P#{pwd} -S#{sname.strip} -X -i#{script} -o#{script}.out"
  script_hash['out'] = "#{script}.out"
  script_hash['validate'] = 'all'

  cmd_hash[cnt.to_s] = script_hash
  cnt += 1
end

# Creates file system structure
fs_hash = Hash.new(0)
fs_hash['cmd'] = "#{node['create_fs']} #{sname} #{node['pltfrm']} #{node['creds']['sybdba']}"
cmd_hash[cnt.to_s] = fs_hash
cnt += 1

# Commands to execute all template files created above.
syb_files.each do |syb_file|
  validate = 'all'
  validate = 'last' if syb_file == 'setup_xp'

  syb_hash = {}
  syb_hash['cmd'] = "isql -U#{user} -P#{pwd} -S#{sname} -i#{SYB_HOME}/tmp/#{syb_file} -o#{SYB_HOME}/tmp/#{syb_file}.out"
  syb_hash['out'] = "#{SYB_HOME}/tmp/#{syb_file}.out"
  syb_hash['validate'] = validate

  cmd_hash[cnt.to_s] = syb_hash
  cnt += 1
end

# Script that sets threshold
thre_hash = Hash.new(0)
thre_hash['cmd'] = "#{node['create_threshold']} #{sname} #{node['creds']['sybdba']} #{node['pltfrm']} #{sname} > #{node['create_threshold']}.out"
thre_hash['out'] = "#{node['create_threshold']}.out"
thre_hash['validate'] = 'all'
cmd_hash[cnt.to_s] = thre_hash
cnt += 1

# Script for sybmgmtdb and job creations.
mgmt_hash = {}
mgmt_hash['cmd'] = "isql -U#{user} -P#{pwd} -S#{sname} -i#{node['sybmgmtdb']} -o#{node['sybmgmtdb']}.out"
mgmt_hash['out'] = "#{node['sybmgmtdb']}.out"
mgmt_hash['validate'] = 'all'
cmd_hash[cnt.to_s] = mgmt_hash
cnt += 1

# Verify if can run the commands
del_full_hash = Hash.new(0)
del_full_hash['cmd'] = node['delete_full_bkp']
cmd_hash[cnt.to_s] = del_full_hash
cnt += 1

del_trn_hash = Hash.new(0)
del_trn_hash['cmd'] = node['delete_trn_bkp']
cmd_hash[cnt.to_s] = del_trn_hash
cnt += 1

server_status_hash = Hash.new(0)
server_status_hash['cmd'] = node['server_status']
cmd_hash[cnt.to_s] = server_status_hash

# Execute commands on the isql shell and backup scripts.
ruby_block 'sybase_cmds_execution' do
  block do
    # Execute each command.
    cmd_hash.each do |_key, value|
      puts value
      scmd = value['cmd']
      puts 'Executing command: ' + scmd
      cmd = 'source /sybase/PGR/SYBASE.sh ;' + scmd
      syb_cmd = Mixlib::ShellOut.new(cmd, user: sybsid)
      syb_cmd.run_command
      puts syb_cmd.stdout
      puts 'error message => ' + syb_cmd.stderr unless syb_cmd.stderr == ''

      # Few isql commands need to be checked, if they executed successfully.
      Common::Helper.validate_out(value['out']) if value['validate'] != 0

      syb_cmd.error!
    end
  end
end

# Create cron tab entries to roll the backups within vm.
cron_entries = [%w(1 delete_full_bkp), %w(5 delete_trn_bkp), %w(7 server_status)]
cron_entries.each do |min, cron_cmd|
  cron "set_cron_#{cron_cmd}" do
    minute min
    hour '1'
    day '*'
    month '*'
    weekday '*'
    command node[cron_cmd]
    action :create
  end
end
