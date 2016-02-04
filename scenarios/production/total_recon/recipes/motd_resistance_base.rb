script "motd_resistance_base" do
  interpreter "bash"
  user "root"
  cwd "/tmp"
  code <<-EOH
  cd /tmp
  wget https://github.com/edurange/scenario-total-recon/raw/master/motd_resistance_base -O /etc/motd
  for each_home in $(ls /home/)
    do cat /etc/motd > /home/$each_home/instructions.txt
  done
  EOH
end