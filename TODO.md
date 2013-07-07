# Edurange TODO list

- Migrate from user-data setup to having user-data only configure puppet.
  Reason being: Any user can request ec2 api from instance to see setup data. In addition, there is a max user data file size.
  Any configuration per node should be done via puppet.

- Document installation in README.md
- Document code walkthrough in WALKTHROUGH.md. Discuss player/team/instance relation.
- Refactor parse()
  - Refactor user parsing
  - Implement ACLs in Subnet layer
- Selective VPC deletion in edurange-cleanup
- Integrate scoring engine
- Implement DSL
- Better integrate cleanup 
  - Create methods in Edurange::Instance for deleting
  - Create object for Edurange::Vpc? Maybe
  - Remove cleanup binary, implement optparse for bin/edurange to allow cleaning up
- Add more exercises
- Enable dry run (don't create vpcs/instances, just parse & print debug info)
- Add interactive console to add users, subnets, instances, etc (and/or cleanup instances or entire vpcs)
