script "install_scapy" do

  interpreter "bash"
  user "root"
  cwd "/tmp"
  code <<-EOH
  git clone https://github.com/JamesSullivan1/scapyHunt
  cd scapyHunt
  python scapyHunt.py &
  
  # groupadd scapy
  # echo '%scapy ALL=(root:root) /usr/sbin/macof' >> /etc/sudoers

  # for f in `find /home -maxdepth 1 -type d`; do
  #  if [ $f != "/home" ] ; then
  #   user=${f:6}
  #    usermod -a -G scapy $user
  #  fi
  # done

  touch /tmp/test
  EOH
  not_if "test -e /tmp/test"

end