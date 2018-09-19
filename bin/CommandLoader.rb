require "#{File.dirname(__FILE__)}/CommandHandler.rb"

class CommandLoader
    COMMAND_FOLDER = "#{File.dirname(__FILE__)}/commands/"
    def self.load(args)
        current_command = args.shift
        all_commands = Dir["#{COMMAND_FOLDER}*"]
            .reject{ |f| File.directory? f}
            .map{ |f| File.basename f }
        
        if all_commands.include? current_command then
            CommandHandler.new("#{COMMAND_FOLDER}#{current_command}", args)
        else
            puts "Using old gdev.."
            system("gdev #{current_command}")
        end
    end
end

