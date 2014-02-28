#!/usr/bin/env bash
cd $HOME/edurange_scoring
rake db:drop; rake db:migrate; rake db:seed;
rails s
