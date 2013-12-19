# Edurange TODO list

- Needs to configure chef: knife.rb, test valid
- AWS test credentials valid, etc
- Plugin system for AWS, OpenStack, etc
- Document installation in README.md
- Document code walkthrough in WALKTHROUGH.md. Discuss player/team/instance relation.

- Rewrite parse to generate activerecord models

- Rewrite scoring engine to have API that accepts users

- Better integrate cleanup 
  - Delete volumes, don't leave them leftover
  - Delete unused IGWs - sometimes they sneak away, just iterate through them all and check usage
  - Create methods in Edurange::Instance for deleting
  - Create object for Edurange::Vpc? Maybe
  - Remove cleanup binary, throw into cli

- Enable dry run (don't create vpcs/instances, just parse & print debug info)
- Add more exercises
- Add interactive console to add users, subnets, instances, etc (and/or cleanup instances or entire vpcs)
