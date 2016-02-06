script "too_many_dirs" do
  interpreter "bash"
  user "root"
  cwd "/tmp"
 code <<-EOH
  cd /home/cobb
  for i in {1..100}
	do
	mkdir dir$i
	cd dir$i
	mySeedNumber=$$`date +%N`; # seed will be the pid + nanoseconds
        myRandomString=$( echo $mySeedNumber | md5sum | md5sum );
        # create our actual random string
        myRandomResult="${myRandomString:2:100}"
	echo $myRandomResult > file.txt
	cd ..
	done
  cd dir66
  echo "to login the user is toodeep, the password is subconcious_security, and the ip address is 10.0.0.16" > file.txt
  cd /tmp
  touch /tmp/test-file2
  EOH
 
  not_if "test -e /tmp/test-file2"
end