script "nat_motd" do
  interpreter "bash"
  user "root"
  cwd "/tmp"
  code <<-EOH
  cd /tmp
  wget https://github.com/edurange/scenario-ssh-inception/raw/master/motd-nat
  mv motd-nat /etc/motd
  EOH
end