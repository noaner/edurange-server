# Edurange

Join us in #edurange on irc.freenode.net!


EDURange is a project sponsored by the National Science Foundation intended to help automate creation of cyber security training games.

## Installation

1. ```curl -sSL https://get.rvm.io | bash -s stable --ruby```
2. ```sudo apt-get install git```
3. ```git clone https://github.com/sboesen/edurange.git```
4. ```git clone https://github.com/sboesen/edurange_scoring.git```
5. ```rvm install ruby-2.0.0-p0```
6. ```rake build```
7. ```gem install /path/to/edurange/pkg/edurange-0.2.0.gem```
8. ```/path/to/bin/make_config_yml yourkeyname```

## Usage

    edurange recon.yml

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
