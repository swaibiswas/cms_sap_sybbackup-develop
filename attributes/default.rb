## Parameters to be passed from the attrib.json
default['tsm_id']                              = 'sapuser1'
default['tsm_pwd']                             = '<dummy>'

# Mostly the node password is same as tsm_pwd.
default['SYBASE']['tsm_node_password']            = '<dummy>'
# TSM Domains for syb, syblog
default['SYBASE']['tsm_full_domain']              = 'NFL_N_SYB'
default['SYBASE']['tsm_incr_domain']              = 'NFL_N_SYBLOG'

# Schedule patterns.
default['SYBASE']['schedule']['full']             = 'WLY_FULL_%'
default['SYBASE']['schedule']['incr']             = 'SYBLOG_LIN_%'

# Details on the request leading this invocation
default['dpe_email']                           = 'dummy_email@us.ibm.com'
default['sr#']                                 = '1-21223442'

# Variables to be set based on env and logic
default['app_type'] = 'non_netweaver' # Applicable values  netweaver or non_netweaver
default['pltfrm'] = 'AMM' # possible values AMM or IC4

default['creds'] = {
  'sa' => '<dummy>',
  'sapsa' => '<dummy>',
  'sapsso' => '<dummy>',
  'sybdba' => '<dummy>'
}

# Disk space requirements for /backup, /sybase/<SID>/log_archive
default['fs_backup_req_free_gb'] = 25
default['fs_logarch_req_free_gb'] = 50

# Static variables to be kept as is.
default['sds_src_location'] = '/sds/BackupAutoScripts/Sybase'
default['create_threshold'] = '/backup/scripts/create_IBM_log_thresholds_on_user_dbs_v6.ksh'
default['create_fs']   = '/backup/scripts/create_db_dumpdir_v4.ksh'
default['dbcreate']    = '/backup/scripts/1dbcreate.sql'
default['createlogin'] = '/backup/scripts/2createlogin_sso.sql'
default['sarole']      = '/backup/scripts/3sarole_dbo.sql'
default['create_sps']  = '/backup/scripts/4create_all_sps.sql'
default['sybmgmtdb']   = '/backup/scripts/5sybmgmtdb_script.sql'

default['tsm_syb_full']     = '/backup/tsm/tsm_sybfull_backup.csh'
default['tsm_syb_purge']    = '/backup/tsm/tsm_sybase_backup_purge.csh'
default['tsm_bkp_launcher'] = '/backup/tsm/tsm_backup_launcher.csh'
default['tsm_prg_launcher'] = '/backup/tsm/tsm_backup_purge_launcher.csh'

default['delete_full_bkp'] = '/backup/scripts/delete_old_full_backups.ksh'
default['delete_trn_bkp'] = '/backup/scripts/delete_old_trn_backups.ksh'
default['server_status'] = '/backup/scripts/server_status.ksh'

default['fs_backup_req_free_gb'] = 25
default['fs_logarch_req_free_gb'] = 50

# Static variables, not to be touched.
default['non_netweaver'] = {
  'cmd_users' => {
    'dbcreate'    => 'sa',
    'createlogin' => 'sa',
    'sarole'      => 'sa',
    'create_sps'  => 'sybdba'
  }
}

# Static variables.
default['netweaver'] = {
  'cmd_users' => {
    'dbcreate'    => 'sapsa',
    'createlogin' => 'sapsso',
    'sarole'      => 'sapsa',
    'create_sps'  => 'sybdba'
  }
}

# variables used by TSM Client configuration
# DbConfig & TSM Config home directory
default['tsm_client_home'] = '/opt/tivoli/tsm/client/ba/bin/'

# Constants defined and used in templates
default['SYBFULL_SERVERNAME']         = 'TSM-SYB'
default['SYBINC_SERVERNAME']          = 'SYB-LOG'
default['COMMMethod']                 = 'TCPip'
default['PASSWORDACCESS']             = 'generate'
default['SYBFULL_SCHEDLOGNAME']       = '/var/tsm/dsmsched_syb.log'
default['SYBFULL_ERRORLOGNAME']       = '/var/tsm/dsmerror_syb.log'

default['SYBINC_SCHEDLOGNAME']        = '/opt/tivoli/tsm/client/ba/bin/dsmsched_log.log'
default['SYBINC_ERRORLOGNAME']        = '/opt/tivoli/tsm/client/ba/bin/dsmerror_log.log'
default['SCHEDLOGRETENTION']          = '30 D'
default['ERRORLOGRETENTION']          = '30 D'
default['MANAGEDSERVICES']            = 'schedule webclient'

# Api home changes from os and architecture of the vm.
# Please note do not have '/' at the end,
# so that compute bit on the vm to append to this path
# e.g /opt/tivoli/tsm/client/api/bin64/
default['tsm_api_home'] = '/opt/tivoli/tsm/client/api/bin'

# Queries for registering SYBASE nodes.
default['SYBASE']['query']['register_full']       = "reg node %{nodename} %{password} us=none dom=%{dom} cont='%{cont}' backdel=yes archdel=yes maxnummp=10 passexp=0 "
default['SYBASE']['query']['register_incr']       = "reg node %{nodename} %{password} us=none dom=%{dom} cont='%{cont}' backdel=yes archdel=yes maxnummp=10 passexp=0 cloptset='AMM_IBM_LIN_SYBLOG'"

# Queries for associating nodes to schedules in SYBASE.
default['SYBASE']['query']['associate']           = 'define assoc %{dom} %{schedule} %{nodename}'
default['SYBASE']['query']['schedule']            = "select schedule_name, sum(usage) as total_usage from ((select schedule_name, 0 as usage from client_schedules where domain_name='%{dom}' and schedule_name like '%{schedpattern}' )union (select asoc.schedule_name, sum(auditocc.total_mb) as usage from associations asoc inner join auditocc on asoc.node_name=auditocc.node_name and asoc.domain_name='%{dom}' and asoc.schedule_name like '%{schedpattern}' group by asoc.schedule_name)) group by schedule_name order by total_usage asc fetch first 1 rows only"
default['SYBASE']['query']['existassoc']          = "select schedule_name from associations where node_name='%{nodename}' and domain_name='%{dom}' and schedule_name like '%{schedpattern}'"
