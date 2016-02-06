script "nat_motd" do
  interpreter "bash"
  user "root"
  cwd "/tmp"
  code <<-EOH
  cd /tmp
  wget https://github.com/edurange/scenario-ssh-inception/raw/master/motd-starting-line
  mv motd-starting-line /etc/motd
  touch /tmp/recipe-motd-done
  EOH
  not_if "test -e /tmp/recipe-motd-done"
end