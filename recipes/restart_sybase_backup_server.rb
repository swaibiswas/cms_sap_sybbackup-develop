# Fetch sid, user names.
sname_cmd = Mixlib::ShellOut.new("ls -ld /sybase/*/sapdata1 | awk '{print $3,$9}'")
sname_cmd.run_command
sybsid, sybdir = sname_cmd.stdout.split()
sname = sybdir.split('/')[2]
sname = sname.strip

# Use supre database user
user = 'sybdba'
pwd = node['creds'][user]

# Shutdown and restart commands.
cmd_list = []
cmd_list.push("isql -U#{user} -P#{pwd} -S#{sname} <<EOF
shutdown SYB_BACKUP
go
EOF")
cmd_list.push("$SYBASE/$SYBASE_ASE/install/RUN_#{sname}_BS &")

# Execute commands on the isql shell and backup scripts.
ruby_block 'sybase_cmds_execution' do
  block do
    # Execute each command.
    cmd_list.each do |scmd|
      puts 'Executing command: ' + scmd
      cmd = 'source /sybase/PGR/SYBASE.sh ;' + scmd
      syb_cmd = Mixlib::ShellOut.new(cmd, user: sybsid)
      syb_cmd.run_command
      puts syb_cmd.stdout
      puts 'error message => ' + syb_cmd.stderr unless syb_cmd.stderr == ''
      syb_cmd.error!
    end
  end
end
