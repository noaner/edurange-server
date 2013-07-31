name  'edurange_base'
maintainer 'Edurange'
maintainer_email 'edurange2@gmail.com'
license 'MIT'
description 'bootstraps all instances with base stuff'
long_description 'no more'
version 1.0
recipe 'edurange_base', 'Base recipe for instances'
%w{ubuntu debian redhat centos fedora freebsd}.each { |os| supports os }
