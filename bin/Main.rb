require "./CommandLoader.rb"

class Main
    def initialize(args)
        puts "Welcome to GDEV 2.0!"
        CommandLoader.load(args)
    end
end

Main.new(ARGV) if __FILE__==$0