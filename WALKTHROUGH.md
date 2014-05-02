Hello! This is a basic code walkthrough of the EDURange project. This is not intended to be a guide on how to use EDURange, rather how the layers in our software stack interact and how the code base is organized.

We have ruby classes for every primitive in EDURange YML - Scenarios, Roles, Subnets, Clouds, Instances. Each have an ActiveRecord class and DB table with null & foreign key checks. This way, each YAML file is verified to make sure it contains valid attributes and only references valid objects at runtime. Additionally, this allows us shared state in multithreading as it's just a plain SQL db. 

Each object has a method, boot, which does some platform independant work and then calls provider_boot. This method is provided dynamically by a "driver" file, of which there is only one currently - the driver file subclasses each primitive and implements provider_boot, calling platform specific API calls in order to create the scenario in the cloud.

The parser is much simpler than it used to be -- all it does is iterate through the YML file creating ruby objects that correspond with the input.

Cookbooks are currently stored in a single file, but will soon be moved to github.com/edurange/edurange_cookbooks. They can be referenced from YML in a role declaration similar to how recon.yml does it.
