class cloudpassage::params {

# (Modify only to adapt to unsupported OSes)
  $packagename = $::operatingsystem ? {
    default => 'cphalo',
  }

  $servicename = $::operatingsystem ? {
    default => 'cphalod',
  }

  $processname = $::operatingsystem ? {
    default => 'cphalo',
  }

  $hasstatus = $::operatingsystem ? {
    /(?i:debian|ubuntu)/        => false,
    /(?i:redhat|centos|fedora)/ => true,
  }

  $configfile = $::operatingsystem ? {
    default => '/etc/cphalo/cphalo.conf',
  }

  $configdir = $::operatingsystem ? {
    default => '/etc/cphalo',
  }

}
