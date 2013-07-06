Hello! This is a basic code walkthrough of the EDURange project. This is not intended to be a guide on how to use EDURange, rather how the layers in our software stack interact and how the code base is organized.

##Layers
* Parser (Home grown ruby - takes a scenario file and generates an AWS scenario)
* Scoring (Home grown - rails. Currently only supports submitting a list of IP addresses used in games like host discovery)
* Host configuration - Puppet & parser. 

##Code

In the parser we have several classes that represent AWS's architecture.

####Cloud
* Contains/manages VPC, contains subnets

####Subnet
* Contains/manages single subnet with 1 or more instances, part of a Cloud. 

####Instance
* Contains/manages single instance, part of a subnet. Creates puppet configuration for instance, and manages user setup script to install/configure puppet agent.