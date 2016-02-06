script "starting_line_script" do
  interpreter "bash"
  user "root"
  cwd "/tmp"
  code <<-EOH
  echo "Go a level deeper. You will find the next host at 10.0.0.7. The trick is that the ssh port has been changed to 123. Good luck! \n User: mal \n Pass: inception" > /home/inceptor/dream1.txt
  EOH
end