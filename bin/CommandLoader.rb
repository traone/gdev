require "./CommandHandler.rb"

class CommandLoader
    COMMAND_FOLDER = "./commands/"
    def self.load(args)
        current_command = args.shift
        all_commands = Dir["#{COMMAND_FOLDER}*"]
            .reject {|f| File.directory? f}
            .map{ |f| File.basename f }
        
        if all_commands.include? current_command then
            CommandHandler.new("#{COMMAND_FOLDER}#{current_command}", args)
        else
            puts "Error! Command #{current_command} not found! Use help."
        end
    end
end

