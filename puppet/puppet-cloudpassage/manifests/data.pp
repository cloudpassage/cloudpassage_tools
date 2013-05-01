class cloudpassage::data {

  # using extlookup here allows per server, env, or hostgroup settings
  # switch to hiera once it goes into Puppet core
  $apikey = extlookup('cloudpassage_apikey','11111111111111111111111111111111111')
  $repokey = extlookup('cloudpassage_repokey','22222222222222222222222222222222222')
  $tags = extlookup('cloudpassage_tags',"$::operatingsystem")

}
