# Edurange

Join us in #edurange on irc.freenode.net!


EDURange is a project sponsored by the National Science Foundation intended to help automate creation of cyber security training games.

## Installation

We will soon publish an AMI you can launch in AWS that has all of this installed and ready to go. If you are on the EDURange Amazon account (or a developer for EDURange without access) please contact Stefan at stefan.boesen [at] gmail.com or weissr [at] evergreen.edu.

Run these on a fresh instance (we used a micro 64 bit Amazon Linux instance, AMI ID ami-fb8e9292)

1. ```sudo yum update```
1. ```sudo yum install git ruby-devel make gcc gcc-g++ sqlite-devel```
3. ```git clone https://github.com/edurange/edurange.git```
4. ```git clone https://github.com/edurange/edurange_scoring.git```
5. ```cd edurange```
5. ```bundle```
6. ```./install.sh```
7. ```vim config/private_pub.yml, set your public IP as the development server. Change the secret, too!```
7. ```vim config/settings.yml, set your ec2_key.```
8. ```/path/to/bin/make_config_yml yourkeyname```
9. ```./start.sh```

Open a web browser to ip:3000. Make sure to allow TCP 3000 and 9292 to the internet. 3000 is the web interface, 9292 is the faye port.

If your IP changes, edit private_pub.yml again and run ./stop.sh, ./start.sh.

## Usage
    
We now have two scenarios - 
- recon.yml, a host discovery game with a scoring site (github.com/sboesen/edurange_scoring)
- elf.yml, an scenario with an instances with where 'ls' has an elf infection. Scoring is being developed to support elf and other scenarios.

Browse to http://ip:3000/scenarios/new, and select from a template if you want to use one of them.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request