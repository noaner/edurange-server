# Edurange

Join us in #edurange on irc.freenode.net!


EDURange is a project sponsored by the National Science Foundation intended to help automate creation of cyber security training games.

## Installation

We will soon publish an AMI you can launch in AWS that has all of this installed and ready to go.

1. ```curl -sSL https://get.rvm.io | bash -s stable --ruby```
2. ```sudo apt-get install git```
3. ```git clone https://github.com/sboesen/edurange.git```
4. ```git clone https://github.com/sboesen/edurange_scoring.git```
5. ```rvm install ruby-2.0.0-p0```
6. ```rake build```
7. ```gem install /path/to/edurange/pkg/edurange-0.2.0.gem```
8. ```/path/to/bin/make_config_yml yourkeyname```

## Usage
    
We now have two scenarios - 
- recon.yml, a host discovery game with a scoring site (github.com/sboesen/edurange_scoring)
- elf.yml, an scenario with an instances with where 'ls' has an elf infection. Scoring is being developed to support elf and other scenarios.
    
    ```edurange scenarios/recon.yml```

    ```edurange scenarios/elf.yml```


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
