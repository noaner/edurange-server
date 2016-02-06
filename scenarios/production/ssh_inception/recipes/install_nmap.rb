script "install_nmap" do
  interpreter "bash"
  user "root"
  cwd "/tmp"
 code <<-EOH
  apt-get -y install nmap
  EOH
end