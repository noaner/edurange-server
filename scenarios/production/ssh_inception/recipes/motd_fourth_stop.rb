script "anon_ftp" do
  interpreter "bash"
  user "root"
  cwd "/tmp"

  code <<-EOH
  cd /tmp
  wget https://github.com/edurange/scenario-ssh-inception/raw/master/motd-fourth-stop
  mv motd-fourth-stop /etc/motd
  touch /tmp/recipe-motd-done
  EOH
  
  not_if "test -e recipe-motd-done"
end