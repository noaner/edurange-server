module Edurange::ECLI
  class Shell < Bombshell::Environment
    include Bombshell::Shell

    prompt_with 'edurange'

    before_launch do
      help
    end

    def help
      Edurange::ECLI::Info.help
    end
  end
end
