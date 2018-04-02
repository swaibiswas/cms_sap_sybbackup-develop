# cms_sap_sybbackup
The cookbook will configure sybase DBA steps and configure TSM syb syblog nodes.


## Pre-requisites
1. TSM_BA Client is already installed on the server using fms_tsm_os cookbook on CMS supermarket
2. Vm has Sap app + Sybase installed. 
3. Is a linux VM.


## Recipes

* [default.rb](recipes/default.rb): The default recipe properly orders and includes
  other recipes from this cookbook to fully manage the backup activation.
  
* [tsm_client_config.rb](recipes/tsm_client_config.rb): This recipe mainly handles all the TSM config, registration of nodes and association with schedules. This recipe internally calls sybase recipe to set up sybase db.

* [syb_config.rb](recipes/syb_config.rb): This recipe mainly handles the sybase config copying sybase scripts, tsm scripts from sds location and updating the files to fill in appropriate dbname, servername, userid variables.


## Attributes

node['fs_backup_req_free_gb'] : 5  :: /backup file system must be 50 GB in size (recommended values).
node['fs_logarch_req_free_gb']: 50 :: /sybase/<sid>/log_archive must be 50 GB in size (recommended values).
Values to the above node can be overriden, to match your needs.
Can override the attributes based on your requirements.

Sample Attribute file for running this cookbook::
```
{  
  "tsm_id":"sapuser1",
  "tsm_pwd":"tsm4cloud",
  "dpe_email":"AMM_Testing@sme.com",
  "sr#":"121232",
  "SYBASE":{  
    "tsm_node_password":"tsm4cloud",
    "tsm_full_domain":"NFL_N_SYB",
    "tsm_incr_domain":"NFL_N_SYBLOG",
    "schedule":{  
      "full":"WLY_FULL_%",
      "incr":"SYBLOG_LIN_%"
    }
  },
  "APP_TYPE":"non_netweaver",
  "pltfrm":"AMM",   
  "creds":{  
    "sa":"<PWD>",
    "sapsa":"<PWD>",
    "sapsso":"<PWD>",
    "sybdba":"<PWD>"
  },
  "fs_backup_req_free_gb" : 5,
  "fs_logarch_req_free_gb": 50
}
```

## License and Author(s)

Copyright &copy; 2017, IBM - All rights reserved

Authors:
* [Bharati Patidar](mailto:bharati@us.ibm.com)
* [Pradip Vedpathak](mailto:pradipv@us.ibm.com)
