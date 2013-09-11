# The profile to set up the Nova controller (several services)
class grizzly::profile::nova::api {
  $api_device = hiera('grizzly::network::api::device')
  $api_address = getvar("ipaddress_${api_device}")

  $management_device = hiera('grizzly::network::management::device')
  $management_address = getvar("ipaddress_${management_device}")

  $explicit_management_address =
    hiera('grizzly::controller::address::management')
  $explicit_api_address = hiera('grizzly::controller::address::api')

  if $management_address != $explicit_management_address {
    fail("Nova API/Scheduler setup failed. The inferred location the
    nova API the grizzly::network::management::device hiera value is
    ${management_address}. The explicit address
    from grizzly::controller::address::management is
    ${explicit_management_address}. Please correct this difference.")
  }

  if $api_address != $explicit_api_address {
    fail("Cinder API/Scheduler setup failed. The inferred location the
    Cinder API the grizzly::network::api::device hiera value is
    ${api_address}. The explicit address
    from grizzly::controller::address::api is ${explicit_api_address}. Please
    correct this difference.")
  }


  # public API access
  firewall { '8774 - Nova API - API Network':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '8774',
    source => hiera('grizzly::network::api'),
  }

  # private API access
  firewall { '8774 - Nova API - Management Network':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '8774',
    source => hiera('grizzly::network::management'),
  }

  firewall { '8775 - Nova Metadata - API Network':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '8775',
    source => hiera('grizzly::network::api'),
  }

  firewall { '8775 - Nova Metadata - Management Network':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '8775',
    source => hiera('grizzly::network::management'),
  }

  $sql_password = hiera('grizzly::nova::sql::password')
  $sql_connection = "mysql://nova:${sql_password}@${management_address}/nova"

  class { '::nova::db::mysql':
    user          => 'nova',
    password      => $sql_password,
    dbname        => 'nova',
    allowed_hosts => hiera('grizzly::mysql::allowed_hosts'),
  }

  class { '::nova::keystone::auth':
    password         => hiera('grizzly::nova::password'),
    public_address   => $api_address,
    admin_address    => $management_address,
    internal_address => $management_address,
    region           => hiera('grizzly::region'),
    cinder           => true,
  }

  $glance_api_server = "http://${management_address}:9292"

  class { '::nova':
    sql_connection     => $sql_connection,
    glance_api_servers => $glance_api_server,
    memcached_servers  => ['127.0.0.1:1211'],
    rabbit_hosts       => [$management_address],
    rabbit_userid      => hiera('grizzly::rabbitmq::user'),
    rabbit_password    => hiera('grizzly::rabbitmq::password'),
    debug              => hiera('grizzly::nova::debug'),
    verbose            => hiera('grizzly::nova::verbose'),
  }

  class { '::nova::api':
    admin_password  => hiera('grizzly::nova::password'),
    auth_host       => $management_address,
    enabled         => true,
  }

  class { [
    'nova::scheduler',
    'nova::objectstore',
    'nova::cert',
    'nova::consoleauth',
    'nova::conductor'
  ]:
    enabled => true,
  }

  class { 'nova::vncproxy':
    host    => $management_address,
    enabled => true
  }
}

