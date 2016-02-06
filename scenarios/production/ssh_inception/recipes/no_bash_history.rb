script "nohistory" do
  interpreter "bash"
  user "root"
  cwd "/tmp"
  code <<-EOH
  cd /tmp
  touch nohistory-done
for f in `find /home -maxdepth 1 -type d`; do 
  if [ $f != "/home" ]  && [ $f != "/home/instructor" ] && [ $f != "/home/ubuntu" ]; then
    echo 'youre all alone here...' > $f/.bash_history
    chown root:root $f/.bash_history
    chmod 644 $f/.bash_history
  fi
done
  EOH
  not_if "test -e /tmp/nohistory-done"
end
