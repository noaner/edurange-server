module Edurange::ECLI
  class Shell < Bombshell::Environment
    include Bombshell::Shell

    prompt_with 'edurange'

    def help
      Edurange::ECLI::Info.help
    end

    def cleanup
      Edurange::Management.cleanup
      puts "Done cleaning up!"
    end

    before_launch do
      Edurange::ECLI::Info.help
    end


  end
end
