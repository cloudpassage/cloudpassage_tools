class cloudpassage::apt {

  File {
    owner   => root,
    group   => root,
    mode    => '0644',
  }

  exec { 'cloudpassage.key':
    command   => 'curl http://packages.cloudpassage.com/cloudpassage.packages.key | apt-key add -',
    path      => '/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin',
    logoutput => on_failure,
    notify    => Exec['apt_update'],
    unless    => 'grep cloudpassage /etc/apt/trusted.gpg 1>/dev/null',
  }

  file { 'cloudpassage.list':
    ensure  => present,
    path    => '/etc/apt/sources.list.d/cloudpassage.list',
    notify  => Exec['apt_update'],
    content => template('cloudpassage/cloudpassage.list.erb'),
  }

  # this assumes you have a central apt class the runs the
  # apt-get update only once for all updates so you don't
  # have problems with apt choking during multiple updates

  #Class['apt::update'] -> Class['cloudpassage::install']

  # in case you don't have an apt update process
  exec { 'apt_update':
    command     => '/usr/bin/apt-get update',
    path        => '/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin',
    logoutput   => on_failure,
    refreshonly => true,
  }

  Exec['apt_update'] -> Class['cloudpassage::install']

}
