# == Class: couchbase::config
#
# Configures the actual couchbase installation. Not meant to be
# launched directly.
#
# === Parameters
# [*size*]
# Initial size (in megabytes) of memory to use for the defined bucket
# [*user*]
# Login user for couchbase
# [*password*]
# Password to login to couchbase servers
# [*server_group*]
# The grouping in which this couchbase cluster lives (necessary)
# [*data_path*]
# The path in which this couchbase cluster stores its data files
#
# === Authors
#
# Justice London <jlondon@syrussystems.com>
# Portions of code by Lars van de Kerkhof <contact@permanentmarkers.nl>
#
# === Copyright
#
# Copyright 2013 Justice London, unless otherwise noted.
#

class couchbase::config (
  $size         = 1024,
  $user         = "$couchbase::user",
  $password     = "$couchbase::password",
  $server_group = 'default',
  $data_path    = undef,
) {

  include couchbase::params 

  exec { 'couchbase-init':
    path        => ['/opt/couchbase/bin', '/usr/bin', '/bin', '/sbin', '/usr/sbin' ],
    command     => "couchbase-cli cluster-init -c localhost:8091 --cluster-init-username=${user} --cluster-init-password='${password}' --cluster-init-port=8091 --cluster-init-ramsize=${size} -u ${user} -p ${password}",
    creates     => '/opt/couchbase/var/lib/couchbase/remote_clusters_cache_v2',
    require     => [ Class['couchbase::install'] ],
    logoutput   => true,
    tries       => 5,
    try_sleep   => 10,
    refreshonly => true,
  }
  
  if $data_path {
    exec { 'couchbase-node-init':
      path        => ['/opt/couchbase/bin', '/usr/bin', '/bin', '/sbin', '/usr/sbin' ],
      command     => "couchbase-cli node-init -c localhost:8091 --node-init-data-path=${data_path} -u ${user} -p ${password}",
      onlyif      => "test \"`couchbase-cli server-info -c localhost:8091 -u ${user} -p ${password} | python -c 'import json,sys;obj=json.load(sys.stdin);print obj[\"storage\"][\"hdd\"][0][\"path\"]'`\" != \"${data_path}\"",
      require     => [ Class['couchbase::install'] ],
      before      => [ Exec['couchbase-init'] ],
      logoutput   => true,
      tries       => 5,
      try_sleep   => 10,
    }
  }

  #Just in case, include concat setup
  include concat::setup

  #Initialize the cluster-building script
  concat { $couchbase::params::cluster_script:
    owner => '0',
    group => '0',
    mode  => '0655',
  }
  concat::fragment { '00_script_header':
    target  => $couchbase::params::cluster_script,
    order   => '01',
    content => template('couchbase/couchbase-cluster-setup.sh.erb'),
  }
  #Collect cluster node entries for config
  Couchbase::Couchbasenode <<| server_group == $server_group |>> ->

  exec { 'couchbase-cluster-setup':
    path      => ['/usr/local/bin', '/usr/bin/', '/sbin', '/bin', '/usr/sbin',
                  '/opt/couchbase/bin'],
    cwd       => '/usr/local/bin',              
    command   => 'couchbase-cluster-setup.sh',
    creates   => '/opt/couchbase/var/.installed',
    require   => [ Concat[$couchbase::params::cluster_script], Exec['couchbase-init'] ],
    returns   => [0, 2],
    logoutput => true,
  }

}
