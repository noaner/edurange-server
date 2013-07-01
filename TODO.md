# Edurange TODO list

- Document installation in README.md
- Document code walkthrough in WALKTHROUGH.md. Discuss player/team/instance relation.
- Refactor parse()
- Selective VPC deletion in edurange-cleanup
- Integrate scoring engine
- Implement DSL
- Better integrate cleanup 
  - Create methods in Edurange::Instance for deleting
  - Create object for Edurange::Vpc? Maybe
  - Remove cleanup binary, implement optparse for bin/edurange to allow cleaning up
- Add more exercises
- Enable dry run (don't create vpcs/instances, just parse & print debug info)
