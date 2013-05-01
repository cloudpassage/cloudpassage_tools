class cloudpassage::firstart {

  exec { 'cloudpassage first start':
    command     => "service cphalod start --api-key=${cloudpassage::data::apikey} --tag=${cloudpassage::data::tags}",
    path        => '/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin',
    logoutput   => on_failure,
    refreshonly => true,
  }

}
