class Template
    attr_accessor :template_file
    attr_accessor :file_location
    attr_accessor :file_name
    def initialize(template_file, file_location, file_name)
        @template_file = "#{Main::MAIN_LOCATION}/#{template_file}"
        @file_location = file_location
        @file_name = file_name
    end
end