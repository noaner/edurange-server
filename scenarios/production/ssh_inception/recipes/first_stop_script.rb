script "first_stop_script" do
  interpreter "bash"
  user "root"
  cwd "/tmp"
  code <<-EOH
  echo "You found it. Well done. The next dream machine lies a few addresses higher. The user name is the first name of the director of a famous movie about dreams and the password is the last name of the protagonist. All lowercase, of course. It is not like we're monsters." > /home/mal/.dream2.txt
  EOH
end