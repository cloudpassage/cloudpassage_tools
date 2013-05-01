class cloudpassage::service {

  service { 'cphalo':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    name       => $cloudpassage::params::servicename,
    start      => "service cphalod start --tag=${cloudpassage::data::tags}",
  }

}
