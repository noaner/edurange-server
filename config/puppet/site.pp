node default {
  include stdlib

  file { "/tmp/test1":
    ensure => present
  } 
  file { "/tmp/derp":
    ensure => present,
    content => $aaaaaafact
  }
}
define install_software {
        $package = $name
        package { $name:
          name => $name,
          ensure => latest,
        }
}
$packages = split($services,',')
install_software{ $packages:; }
