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

## Setup

As an instructor, you will use an Instructor VM that will allow you to run scenarios and observe the scoring
events that you can use for assessment. The edurange code that runs the two scenarios that we have is
already installed on the Instructor VM and it launches new VM instances and configures them. Currently,
we have created one instructor machine that you can use or you can make a copy and customize it for your
class. You can start and stop different exercises from the Instructor machine. The AWS console gives you
a way to start and stop the instructor machine and to kill any Amazon Instances (AMIs) that were created
by the instructor machine. For each scenario, there a YAML file in the edurange directory that specifies the
exercise. It includes the number of students and what their passwords are. These can be changed in the
YAML file subject to the resource limitations of the account. In general, students will each have their own
EC2 instances to log into and work on the exercises (first they connect through an external IP address to a
Gateway). The next section will lead you through starting an instructor machine and how to use it to create
the scenarios. There are two modes for using EDURange. You may be using your own account or you may
be using the EDURange group account. The use of those two modes will described separately.


### Starting the instructor machine from the EDURange account
If you are going to use the EDURange account, you will need the URL for the EDURange account, a
username and password, and you will need to be a member of the edurange group or the edu
fac group. In
the future, we will provide a form on this website for you to request access, but for now send e-mail. Once



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
