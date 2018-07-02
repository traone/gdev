class CommandHandler
    EVAL_START = ".:RUBY:."
    EVAL_END = ".:/RUBY:."

    def initialize(command_file, args)
        read_file(command_file, args)
    end

    def handle_command(line)
        return system(line)
    end

    def evaluate(eval_container)
        eval(eval_container)
    end

    def read_file(command_file, args)
        File.open(command_file, "r") do |f|
            eval_container = "args = #{args}\n"
            eval_in_progress = false
            f.each_line do |line|
                if line.strip == EVAL_START
                    eval_in_progress = true
                elsif line.strip == EVAL_END
                    eval_in_progress = false
                    evaluate(eval_container)
                    eval_container = "args = #{args}\n"
                else
                    if eval_in_progress
                        eval_container.concat(line)
                    else
                        args.push(handle_command(line))
                    end
                end
            end
        end
    end
end