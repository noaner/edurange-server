name  'edurange_data_generation'
maintainer 'Edurange'
maintainer_email 'edurange2@gmail.com'
license 'MIT'
description 'Generates strace data'
long_description 'no more'
version 1.0
recipe 'edurange_data_generation', 'Generates strace data on associated instance'
%w{ubuntu debian redhat centos fedora freebsd}.each { |os| supports os }
depends "user"
depends "sudo"
