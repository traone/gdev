require "yaml"

class Create

    class << self

        def start(args)
            cfg_file = args.length > 0 ? args[0] : "gdev2-create.yaml"

            if (File.file?(cfg_file))
                puts "Config file found, generating project.."
                config = YAML.load(File.read(cfg_file));
            else
                puts "Config file not found, starting a wizard.."
                config = { }
            end

            self.handle_args(config)
        end

        def get_defaults(type)
            defaults = Hash.new
            file_name = ENV['HOME']+'/.gdev/gdevconf.yml'
            if File.exist?(file_name)
                config = YAML.load(File.read(file_name))
                defaults = config['create']['defaults'][type]
            else
                puts "Could not read default file!"
            end
            return defaults
        end

        def is_yes(yesno)
            noes = [
                "n",
                "no",
                "NO",
                "N"
            ]
            if yesno.empty? || ( noes.include? yesno )
                return false
            else
                return true
            end
        end

        def handle_args(config)
            globals = {
                "name" => "",
                "session_db" => 3,
                "create_buckets" => false,
                "is_multisite" => false
            }

            defaults = get_defaults("wordpress")

            actions = {
                "project_name" => -> (name) {
                    raise ArgumentError, "Project name can't contain whitespaces" unless !name.include?(" ")
                    puts "Project name set"
                    globals["name"] = name

                    puts "Cloning WP project to project folder.."
                    system("git clone git@github.com:devgeniem/wp-project.git #{name}")

                    puts "Removing .git folder from project folder.."
                    system("rm -rf #{name}/.git")

                    puts "Cloning dustpress-theme to project folder.."
                    system("git clone git@github.com:devgeniem/the-dustpress-theme.git #{name}/web/app/themes/#{name}")

                    puts "Removing .git folder from theme folder.."
                    system("rm -rf #{name}/web/app/themes/#{name}/.git")

                    # replace all name (namespace) references from all files from this project to your project name
                    puts "Replacing 'name' strings from all project files with '#{name}'..."

                    name_file_names = {
                        "#{name}/docker-compose.yml" => {
                            "THEMENAME" => name,
                            "asiakas.test" => "#{name}.test"
                        },
                        "#{name}/docker-compose-ubuntu.yml" => {
                            "THEMENAME" => name,
                            "asiakas.test" => "#{name}.test"
                        },
                        "#{name}/docker-compose-gcloud.yml" => {
                            "THEMENAME" => name,
                            "asiakas.test" => "#{name}.test"
                        },
                        "#{name}/kontena-stage.yml" => {
                            "image: devgeniem/client-asiakas" => "image: gcr.io/#{defaults["service_accounts"]["stage"]}/client-#{name}",
                            "asiakas" => name,
                            "Asiakas" => name.capitalize
                        },
                        "#{name}/kontena-production.yml" => {
                            "image: devgeniem/client-asiakas" => "image: gcr.io/#{defaults["service_accounts"]["production"]}/client-#{name}",
                            "asiakas" => name,
                            "Asiakas" => name.capitalize
                        },
                        "#{name}/gcloud/cloudbuild_production.yaml" => {
                            "THEMENAME" => name,
                            "asiakas.test" => "#{name}.test",
                            "PROJECTNAME" => "client-#{name}"
                        },
                        "#{name}/gcloud/cloudbuild_stage.yaml" => {
                            "THEMENAME" => name,
                            "asiakas.test" => "#{name}.test",
                            "PROJECTNAME" => "client-#{name}"
                        },
                        "#{name}/gcloud/trigger_stage.json" => {
                            "REPO-OWNER"  => "devgeniem", #TODO: from config
                            "GCP_PROJECT" => "#{defaults["service_accounts"]["stage"]}",
                            "PROJECTNAME" => "client-#{name}"
                        },
                        "#{name}/gcloud/trigger_production.json" => {
                            "REPO-OWNER"  => "devgeniem", #TODO: from config
                            "GCP_PROJECT" => "#{defaults["service_accounts"]["production"]}",
                            "PROJECTNAME" => "client-#{name}"
                        },
                        "#{name}/tests/acceptance.suite.yml" => {
                            "asiakas.test" => "#{name}.test"
                        }
                    }

                    name_file_names.each do |file_name, data|
                        text = File.read(file_name)

                        new_contents = text

                        data.each do |replace, with|
                            new_contents = new_contents.gsub(replace, with)
                        end

                        File.open(file_name, "w") { | file |
                            file.puts new_contents
                        }
                    end

                },
                "php_session_redis_db" => -> (session_db) {
                    session_db = session_db.to_i
                    raise ArgumentError, "Redis id has to be numeric!" unless session_db.is_a? Integer
                    globals["session_db"] = session_db
                    name_file_names = {
                        "#{globals["name"]}/kontena-stage.yml" => {
                            "replace" => /PHP_SESSION_REDIS_DB: \d/,
                            "with"    => "PHP_SESSION_REDIS_DB: #{session_db}"
                        },
                        "#{globals["name"]}/kontena-production.yml" => {
                            "replace" => /PHP_SESSION_REDIS_DB: \d/,
                            "with"    => "PHP_SESSION_REDIS_DB: #{session_db}"
                        },
                    }

                    puts "Replacing redis session db.."
                    name_file_names.each do |file_name, data|
                        text = File.read(file_name)
                        new_contents = text.gsub(data["replace"], data["with"])
                        File.open(file_name, "w") {|file| file.puts new_contents }
                    end
                },
                "add_default_repositories" => -> (yesno) {
                    if !is_yes(yesno)
                        return
                    else
                        repositories = defaults["extra_repositories"]
                        puts "Adding repositories.."
                        repositories.each do | repository |
                            repository_cmd = "composer config #{repository}"
                            puts "cd #{globals["name"]} && #{repository_cmd}"
                            system("cd #{globals["name"]} && #{repository_cmd}")
                        end
                        packages = defaults["extra_packages"]
                        puts "Requiring packages.."
                        packages.each do | package |
                            require_cmd = "composer require #{package}"
                            puts "cd #{globals["name"]} && #{require_cmd}"
                            system("cd #{globals["name"]} && #{require_cmd}")
                        end
                        puts "Running composer install.."
                        system("cd #{globals["name"]} && composer install")
                    end
                },
                "is_multisite" => -> (yesno) {
                    if is_yes(yesno)
                        globals["is_multisite"] = true
                        system("cd #{globals["name"]} && composer require humanmade/mercator:dev-master")
                        theme_root = "#{globals["name"]}/web/app/themes/#{globals["name"]}"
                        setup_file = "#{theme_root}/lib/Setup.php"
                        contents = File.read(setup_file)
                        new_contents = contents.gsub(/Setup hooks./, "Setup hooks.\n\t\t\\add_filter( 'mercator.sso.enabled', '__return_false' );")
                        File.open(setup_file, "w") {|file| file.puts new_contents }
                        application_file = "#{globals["name"]}/config/application.php"
                        multisite_content = [
                            "/* Multisite */",
                            "define( 'WP_ALLOW_MULTISITE', true );",
                            "define( 'MULTISITE', true );",
                            "define( 'SUBDOMAIN_INSTALL', true );",
                            "$base = '/';",
                            "// Read main site address from SERVER_NAME",
                            "define( 'DOMAIN_CURRENT_SITE', env('SERVER_NAME') );",
                            "define( 'PATH_CURRENT_SITE', '/' );",
                            "define( 'SITE_ID_CURRENT_SITE', 1 );",
                            "define( 'BLOG_ID_CURRENT_SITE', 1 );"
                        ]

                        open("#{application_file}", 'a') { |f|
                            multisite_content.each do | row |
                                f.puts("#{row}\n")
                            end
                        }


                    else

                        # Replace WPMS if not multisite
                        wpms_replace = {
                            "#{globals["name"]}/kontena-stage.yml" => {
                                "WPMS" => "WP",
                            },
                            "#{globals["name"]}/kontena-production.yml" => {
                                "WPMS" => "WP",
                            }
                        }

                        wpms_replace.each do |file_name, data|
                            text = File.read(file_name)

                            new_contents = text
                            data.each do |replace, with|
                                new_contents = new_contents.gsub(replace, with)
                            end

                            File.open(file_name, "w") { | file |
                                file.puts new_contents
                            }
                        end

                    end

                },
                "create_buckets" => -> (yesno) {
                    if is_yes(yesno)
                        globals["create_buckets"] = true
                        puts "Login to Google Cloud.."
                        #system("gcloud auth login")

                        puts("Creating service accounts..")
                        system("gcloud config set project #{defaults["service_accounts"]["dev"]}")
                        system("gcloud iam service-accounts create #{globals["name"]}-development --display-name \"#{globals["name"]} development\"")
                        system("gcloud config set project #{defaults["service_accounts"]["stage"]}")
                        system("gcloud iam service-accounts create #{globals["name"]}-stage --display-name \"#{globals["name"]} stage\"")
                        system("gcloud config set project #{defaults["service_accounts"]["production"]}")
                        system("gcloud iam service-accounts create #{globals["name"]}-production --display-name \"#{globals["name"]} production\"")

                        puts("Creating buckets..")
                        system("gsutil mb -l eu -p #{defaults["service_accounts"]["dev"]} gs://#{globals["name"]}-dev")
                        system("gsutil mb -l eu -p #{defaults["service_accounts"]["stage"]} gs://#{globals["name"]}-stage")
                        system("gsutil mb -l eu -p #{defaults["service_accounts"]["production"]} gs://#{globals["name"]}-production")

                        puts("Settings bucket permissions..")
                        system("gsutil acl ch -u #{globals["name"]}-dev@#{defaults["service_accounts"]["dev"]}.iam.gserviceaccount.com:W gs://#{globals["name"]}-dev")
                        system("gsutil acl ch -u #{globals["name"]}-stage@#{defaults["service_accounts"]["stage"]}.iam.gserviceaccount.com:W gs://#{globals["name"]}-stage")
                        system("gsutil acl ch -u #{globals["name"]}-production@#{defaults["service_accounts"]["production"]}.iam.gserviceaccount.com:W gs://#{globals["name"]}-production")

                        puts("Creating keys for service accounts..")
                        system("gcloud iam service-accounts keys create #{globals["name"]}-dev.json --iam-account #{globals["name"]}-dev@#{defaults["service_accounts"]["dev"]}.iam.gserviceaccount.com")
                        system("gcloud iam service-accounts keys create #{globals["name"]}-stage.json --iam-account #{globals["name"]}-stage@#{defaults["service_accounts"]["stage"]}.iam.gserviceaccount.com")
                        system("gcloud iam service-accounts keys create #{globals["name"]}-production.json --iam-account #{globals["name"]}-production@#{defaults["service_accounts"]["production"]}.iam.gserviceaccount.com")
                        system("cat #{globals["name"]}-dev.json | python -c 'import sys, json; print json.dumps(json.load(sys.stdin),sort_keys=True)' > #{globals["name"]}-dev.min.json")
                        system("cat #{globals["name"]}-stage.json | python -c 'import sys, json; print(json.dumps(json.load(sys.stdin),sort_keys=True))' > #{globals["name"]}-stage.min.json")
                        system("cat #{globals["name"]}-production.json | python -c 'import sys, json; print(json.dumps(json.load(sys.stdin),sort_keys=True))' > #{globals["name"]}-production.min.json")
                    end
                },
                "install_kontena_stacks" => -> (yesno) {
                    if is_yes(yesno)
                        puts "Building initial images.."
                        system("cd #{globals["name"]} && docker build --pull -t gcr.io/#{defaults["service_accounts"]["stage"]}/client-#{globals["name"]}:stage .")
                        system("cd #{globals["name"]} && docker build --pull -t gcr.io/#{defaults["service_accounts"]["production"]}/client-#{globals["name"]}:latest .")

                        puts "Pushing initial images.."
                        system("gcloud config set project #{defaults["service_accounts"]["stage"]}")
                        system("docker push gcr.io/#{defaults["service_accounts"]["stage"]}/client-#{globals["name"]}:stage")
                        system("gcloud config set project #{defaults["service_accounts"]["production"]}")
                        system("docker push gcr.io/#{defaults["service_accounts"]["production"]}/client-#{globals["name"]}:latest")

                        puts "Login to Kontena.."
                        system("kontena cloud login")

                        puts "Selecting stage platform.."
                        system("kontena master use geniem-stage")
                        puts "Installing stage stack.."
                        stage_stack_cmd = "kontena stack install kontena-stage.yml"
                        system("cd #{globals["name"]} && #{stage_stack_cmd}")
                        if globals["create_buckets"] == true
                            puts "Setting stage GOOGLE_CLOUD_STORAGE_ACCESS_KEY.."
                            system("kontena vault write #{globals["name"]}-google-cloud-storage-access-key \"$(cat #{globals["name"]}-stage.min.json)\"")
                        end

                        puts "Selecting production platform.."
                        system("kontena master use geniem-production")
                        puts "Installing production stack.."
                        production_stack_cmd = "kontena stack install kontena-production.yml"
                        system("cd #{globals["name"]} && #{production_stack_cmd}")
                        if globals["create_buckets"] == true
                            puts "Setting production GOOGLE_CLOUD_STORAGE_ACCESS_KEY.."
                            system("kontena vault write #{globals["name"]}-google-cloud-storage-access-key \"$(cat #{globals["name"]}-production.min.json)\"")
                        end
                    end
                },
                "create_databases" => -> (yesno) {
                    puts "Give stage MySQL root password"
                    mysql_pass = gets
                    puts "Selecting stage platform.."
                    system("kontena master use geniem-stage")
                    password = `openssl rand -hex 42`.strip
                    new_db = "create database \\`client-#{globals["name"]}\\`; CREATE USER \\`client-#{globals["name"]}\\`@\\`localhost\\` IDENTIFIED BY '#{password}'; grant all privileges on \\`client-#{globals["name"]}\\`.* to \\`client-#{globals["name"]}\\`@\\`localhost\\`; flush privileges;"
                    cmd = "sudo mysql -uroot -p#{mysql_pass.strip} --execute=\"#{new_db}\""
                    ssh = system("ssh #{defaults["kontena"]["platforms"]["geniem/stage"]["database"]} '#{cmd}'")
                    system("kontena vault write client-#{globals["name"]}-mysql-password #{password}")

                    puts "Give production MySQL root password"
                    mysql_pass = gets
                    puts "Selecting production platform.."
                    system("kontena master use geniem-production")
                    password = `openssl rand -hex 42`.strip
                    new_db = "create database \\`client-#{globals["name"]}\\`; CREATE USER \\`client-#{globals["name"]}\\`@\\`localhost\\` IDENTIFIED BY '#{password}'; grant all privileges on \\`client-#{globals["name"]}\\`.* to \\`client-#{globals["name"]}\\`@\\`localhost\\`; flush privileges;"
                    cmd = "sudo mysql -uroot -p#{mysql_pass.strip} --execute=\"#{new_db}\""
                    ssh = system("ssh #{defaults["kontena"]["platforms"]["geniem/production"]["database"]} '#{cmd}'")
                    system("kontena vault write client-#{globals["name"]}-mysql-password #{password}")

                    puts "Databases created."
                },
                "initialize_gcp" => -> (yesno) {
                    if is_yes(yesno)
                        puts "Initializing GCP"
                        system("gcloud config set project #{defaults["service_accounts"]["stage"]}")
                        system("gcloud alpha builds triggers create github --trigger-config=#{name}/gcloud/trigger_stage.json")
                        system("gcloud config set project #{defaults["service_accounts"]["production"]}")
                        system("gcloud alpha builds triggers create github --trigger-config=#{name}/gcloud/trigger_production.json")
                        puts "GCP triggers created. Connect GitHub to GCP via browser to enable."
                    end
                }
            }

            actions.each do | command, action |
                if (config.key?(command))
                    action.call(config[command])
                else
                    beautify = command.capitalize.gsub(/_/, " ")
                    puts "#{beautify} not set."
                    puts "#{beautify}:"
                    argument = gets
                    argument = argument.strip
                    action.call(argument)
                end
            end

            # After setup..
            puts "Starting gdev.."
            system("cd #{globals["name"]} && gdev up")
            puts "Give admin username:"
            admin_user = gets
            puts "Give admin email:"
            admin_email = gets
            puts "Give admin password:"
            admin_password = gets
            wp_core_cmd = "gdev exec wp core install --url=#{globals["name"].strip}.test --title=#{globals["name"].strip} --admin_user=#{admin_user.strip} --admin_email=#{admin_email.strip} --admin_password=#{admin_password.strip}"
            puts "Installing WP core.."
            puts wp_core_cmd
            system("cd #{globals["name"]} && #{wp_core_cmd}")
            puts "Activating plugins.."
            system("cd #{globals["name"]} && gdev exec wp plugin activate --all")
            if globals["is_multisite"] == true
                system('cd '+globals["name"]+' && gdev exec wp core multisite-convert --title="Multisiten Sivustot" --subdomains')
            end
        end

    end
end

Create.start(args)