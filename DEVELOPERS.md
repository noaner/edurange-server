
## Installation for creating an instructor machine

We will soon publish an AMI you can launch in AWS that has all of this installed and ready to go. If you are on the EDURange Amazon account (or a developer for EDURange without access) please contact Stefan at stefan.boesen [at] gmail.com or weissr [at] evergreen.edu.

Run these on a fresh instance (we used a micro 64 bit Amazon Linux instance, AMI ID ami-fb8e9292)

1. ```sudo yum update```
2. ```sudo yum install git ruby-devel make gcc gcc-g++ sqlite-devel```
3. ```git clone https://github.com/edurange/edurange.git```
4. ```git clone https://github.com/edurange/edurange_scoring.git```
5. ```cd edurange```
6. ```bundle```
7. ```./install.sh```
8. ```vim config/private_pub.yml, set your public IP as the development server. Change the secret, too!```
9. ```vim config/settings.yml, set your ec2_key.```
10. ```/path/to/bin/make_config_yml yourkeyname```
11. ```./start.sh```

Open a web browser to ip:3000. Make sure to allow TCP 3000 and 9292 to the internet. 3000 is the web interface, 9292 is the faye port.

If your IP changes, edit private_pub.yml again and run ./stop.sh, ./start.sh.

