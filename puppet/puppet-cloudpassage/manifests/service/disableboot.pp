class cloudpassage::service::disableboot inherits cloudpassage::service {

  Service['cphalo'] { enable => false, }

}
