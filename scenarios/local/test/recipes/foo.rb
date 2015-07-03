script "install_elf" do
  interpreter "bash"
  user "root"
  cwd "/tmp"

  code <<-EOH
  echo 'sup' > /tmp/sup
  EOH

  not_if "test -e /tmp/test-file"
end