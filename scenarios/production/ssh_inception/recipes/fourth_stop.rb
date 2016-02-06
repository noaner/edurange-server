script "anon_ftp" do
  interpreter "bash"
  user "root"
  cwd "/tmp"

  code <<-EOH
  iptables -A INPUT -s 10.0.0.15 -j DROP
  touch /tmp/done-ip-tables
  EOH
  
  not_if "test -e /tmp/done-ip-tables"
end