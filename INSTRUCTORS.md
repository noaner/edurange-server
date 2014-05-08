# Edurange

Join us in #edurange on irc.freenode.net!


EDURange is a project sponsored by the National Science Foundation intended to help automate creation of cyber security training games.
## Introduction
This is a draft. A working version should be ready by June 1. EDURange is both a collection of interactive, collaborative cybersecurity exercises and a framework for creating these exercises. Currently, we have
two exercises: Recon I and ELF Infection. Recon I was the first exercise created and was based on a scenario
from PacketWars. It focuses on reconnaissance to determine hosts in an unknown network. The standard
tool for this is nmap, and while the student will need to learn how to use that tool in order to do this exercise,
that is not the most important learning goal. The most important learning goal is developing analytical skills
with respect to complex systems and complex data. Similarly, the Elf Infection exercise uses standard tools
such as netstat but requires that students reason about the behavior of a complex system to discover which
binary is infected and what it is doing, e.g. it opens a port and listens for connections, which it should not
be doing. There are several more exercises planned, and they can be found in the Future Work section

## Installation

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