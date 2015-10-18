script "install_strace" do

  interpreter "bash"
  user "root"
  cwd "/tmp"
  code <<-EOH
  cd /tmp
  git clone https://github.com/kahea/strace-lyn
  cd /tmp/strace-lyn
  ./install
  cd /tmp
  rm -rf /tmp/strace-lyn
  touch /tmp/test
  EOH

  not_if "test -e /tmp/test"

end