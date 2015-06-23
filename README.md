# EDURange Documentation
## What is it?

EDURange is an NSF-funded project with the aim of building a platform for cloud-based interactive computer security exercises. 


## Installation
First, clone this git repository:
```bash
git clone https://github.com/edurange/edurange.git
```

If you haven't already installed RVM (Ruby Version Manager), follow this [guide](https://rvm.io/rvm/install). This project uses Ruby 2.1->2.2.2 so use RVM to install and select the correct version of Ruby:
```bash
rvm install 2.2.2
rvm use 2.2.2
```

You may have to do something like: `bin/bash --login` in order to set the RVM ruby version (which doens't refer to the system ruby version).

Also, install bundler (to take care of gem dependencies) and the rails framework:
Debian/Ubuntu Linux:
```bash
sudo apt-get install rubygems
sudo apt-get install rails
sudo gem install bundler
```
Fedora/Red Hat Linux
```bash
sudo yum install rubygems
sudo yum install rubygem-{rails}
sudo gem install bundler
```

To finish up the installation, yank and update all the gem dependencies:
```bash
bundle update
bundle install
```

Now you should be all ready to go!

## Development



