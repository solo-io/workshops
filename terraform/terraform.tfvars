# Default parameters
project       = "solo-test-236622"
machine_type  = "n1-standard-1"
zone          = "europe-west4-a"
vm_image      = "ubuntu-2004-focal-v20210510"
num_instances = 1

# TO BE EDITED #
environments = {
  #workshop1 = {
  #  machine_type  = "n1-standard-8"
  #  zone          = "europe-west4-a"
  #  num_instances = 0
  #  vm_image      = "ubuntu-2004-focal-v20210211"
  #}
  personal1 = {
    num_instances = 1
    machine_type  = "n1-standard-8"
  }
}
