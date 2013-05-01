class cloudpassage::service::disable inherits cloudpassage::service {

  Service['cphalo'] { ensure => stopped, enable => false, }

}
