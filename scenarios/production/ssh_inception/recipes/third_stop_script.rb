script "third_stop_script" do
  interpreter "bash"
  user "root"
  cwd "/tmp"
 code <<-EOH
  mkdir /home/cobb/.ssh
  echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCuyWxWPb13xX8MEJ5yqktdCyW9MenY88OFjEoo4rnTDIPnt3dWfb0P32DdqSEXwsorC17IBa71TOODF4XKNdS/ndPFs2fhNtff93dcYIiWpHbLu2TZg6QB+WaX/SathspjCDMez2c6FoFJdoXyxOX1+WiD//DXYVAbk96f78x3/5Oy5cE02ic+L3XLMy+6dRfYbKHouc3gWU5n1L0rWvlJfv45fB1pdldF+Nidk9c7HI/6WWm5vLOUrBJKhRydjJ7yqhS7gn2PQt7KrBYygQZNhWc1+WlnJl3HNPshVGx8hK+rMIcOPgJ6QGIfpce6WpV2FRvH+Klc9f5yDSAK5tDJ christopher@5a18a5ce-a622-4aba-8407-47442c207e58
" >> /home/cobb/.ssh/authorized_keys
  cd /tmp
  touch test-file
  EOH

  not_if "test -e /tmp/test-file"
end