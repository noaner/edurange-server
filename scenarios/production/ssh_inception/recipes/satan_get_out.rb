script "motd" do
  interpreter "bash"
  user "root"
  cwd "/tmp"
  code <<-EOH
  cd /tmp
  wget https://github.com/edurange/scenario-ssh-inception/raw/master/satan-get-out
#for f in `find /home -maxdepth 1 -type d`; do 
#  if [ $f != "/home" ]  && [ $f != "/home/instructor" ] && [ $f != "/home/ubuntu" ]; then
    echo 'cat /tmp/satan-get-out' >> /etc/profile
    echo 'exit' >> /etc/profile
#  fi
#done
  EOH
  not_if "test -e /tmp/satan-get-out"
end
