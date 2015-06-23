# EDURange Documentation
## What is it?

EDURange is an NSF-funded project with the aim of building a platform for cloud-based interactive computer security exercises. 


## Installation
First, clone this git repository:
```bash
git clone https://github.com/edurange/edurange.git
```

If you haven't already installed RVM (Ruby Version Manager), follow this [guide](https://rvm.io/rvm/install). This project uses Ruby 2.1.5 so use RVM to install and select the correct version of Ruby:
```bash
rvm install 2.1.5
rvm use 2.1.5
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
Once you've got the development environment put together the dev server can be started.
If this is your first time running the edurange you'll probably have to run a database migration by saying:
```bash
bin/rake db:migrate RAILS_ENV=development
```

Now bootup the developement server:
```bash
rails server
```

Point your web browser to localhost:3000 and you should see something like this:
![alt tag](http://i.imgur.com/2HR5k9K.jpg?1)

Currently you have no users locally stored in your database, so we'll have to drop into a ruby interpreter and create one. Open a new terminal, cd to the edurange directory and execute the following:
```bash

```