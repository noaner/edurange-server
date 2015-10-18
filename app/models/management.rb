class Management
  def debug(message)
    # PrivatePub.publish_to "/cleanup", log_message: message
  end
  def purge
    Scenario.delete_all
    Cloud.delete_all
    Subnet.delete_all
    Instance.delete_all
    Player.delete_all
    Group.delete_all
    Role.delete_all
    RoleRecipe.delete_all
    Recipe.delete_all
    InstanceGroup.delete_all
    InstanceRole.delete_all
    Question.delete_all
    Answer.delete_all
    debug "Finished purging local DB!"
  end
  # handle_asynchronously :purge

  def showresources
    puts Scenario.all
    puts Cloud.all
    puts Subnet.all
    puts Instance.all
    puts Player.all
    puts Group.all
    puts Role.all
    puts RoleRecipe.all
    puts Recipe.all
    puts InstanceGroup.all
    puts InstanceRole.all
    puts Question.all
    puts Answer.all
  end

end
