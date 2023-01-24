#!/usr/bin/env ruby
# frozen_string_literal: true

###
# Grit is a way to manage multiple repos in a git repository seamlessly using the git CLI tools
###

require "yaml"
require "fileutils"
require "date"

# Grit Class
class Grit
  VERSION = "2022.10.25"

  def version
    VERSION
  end

  ###
  # Display options for grit
  ###
  def help
    puts "OPTIONS:\n\n"
    puts " add-all                       - add all directories in the current directory to config.yml"
    puts " add-repository <name> <dir>   - add repo and dir to config.yml"
    puts " config                        - show current config settings"
    puts " clean-config                  - remove any missing direcotries from config.yml"
    puts " clean-history                 - clear entries from history.log file"
    puts " convert-config                - convert conf from sym to string"
    puts " destroy                       - delete current grit setup including config and .grit directory"
    puts " help                          - display list of commands"
    puts " history                       - display history of grit requiests in this directory"
    puts " init <dir> (optional)         - create grit config.yml file in .grit dir"
    puts " remove-repository <name>      - remove specified repo from config.yml"
    puts " reset                         - reset current grit setup to the initial config"
    puts " on <repo> <action>            - execute git action on specific repo"
    puts " version                       - get current grit version\n\n"
  end

  ###
  # Append command to history file
  ###
  def append_history(record)
    history_file = File.join(FileUtils.pwd, ".grit/history.log")
    unless File.exist?(history_file)
      File.write(history_file, "")
    end
    now = DateTime.now.strftime('[%Y-%m-%d %H:%M:%S]')
    File.write(history_file, now + " grit " + record.join(' ') + "\n", mode: 'a+')
  end

  ###
  # Display history of grit commands
  ###
  def display_history
    history = IO.read(File.join(FileUtils.pwd, ".grit/history.log"))
    puts history
  end

  ###
  # Clear  history file
  ###
  def clear_history
    File.write(File.join(FileUtils.pwd, ".grit/history.log"), "")
  end

  ###
  # Create .grit dir and config.yml file
  ###
  def initialize_grit
    location = Dir.pwd

    if File.directory?(location)
      directory = File.join(location, ".grit")
      FileUtils.mkdir(directory) unless File.directory?(directory)

      config_file = directory + "/config.yml"
      unless File.exist?(config_file)
        config = {}
        config["root"] ||= location
        config["repositories"] ||= []
        config["ignore_root"] = true

        File.open(directory + "/config.yml", "w") { |f| YAML.dump(config, f) }
      end

      history_file = directory + "/history.log"
      unless File.exist?(history_file)
        File.write(history_file, "")
      end
    else
      puts "Directory doesn't exist!"
    end
  end

  ###
  # Reset .grit dir and config.yml
  ###
  def reset
    destroy
    initialize_grit
  end

  ###
  # Remove .grit dir and config.yml
  ###
  def destroy
    location = Dir.pwd
    directory = File.join(location, ".grit")

    if File.directory?(directory)
      puts "Are you sure? (y/n): "
      input = $stdin.gets.strip
      exit unless input.downcase == "y"

      File.delete(directory + "/config.yml")
      Dir.delete(directory)
      puts "Grit configuration files have been removed from #{location}"
    else
      puts "#{location} is not a grit project!"
    end
  end

  ###
  # Return current config as json
  ###
  def load_config
    config = File.open(File.join(FileUtils.pwd, ".grit/config.yml")) { |f| YAML.safe_load(f) }
    config["repositories"].unshift("name" => "Root", "path" => config["root"]) unless config["ignore_root"]
    config
  rescue Psych::DisallowedClass
    puts "Could not load config.  Probably need to perform a `grit convert-config` to string names"
    exit 1
  rescue Errno::ENOENT
    puts "Could not load config.  Are you sure this is a grit directory?"
    exit 1
  end

  ###
  # Write config, passed in config as json, to disk as yaml
  ###
  def write_config(config)
    File.open(File.join(FileUtils.pwd, ".grit/config.yml"), "w") { |f| YAML.dump(config, f) }
  end

  ###
  # Display config
  ###
  def display_config
    config = load_config
    puts config.to_yaml
  end

  ###
  # Convert config yaml from symbols to strings
  ###
  def convert_config
    original_config = File.read(File.join(FileUtils.pwd, ".grit/config.yml"))
    new_config = YAML.safe_load(original_config.gsub(":repositories:", "repositories:")
                                               .gsub(":root:", "root:")
                                               .gsub(":ignore_root:", "ignore_root:")
                                               .gsub(":name:", "name:")
                                               .gsub(":path:", "path:"))
    new_config.to_yaml
    write_config(new_config)
  end

  ###
  # Add repository to config
  ###
  def add_repository(args)
    config = load_config
    name = args[0]
    path = args[1] || args[0]

    git_dir = path + "/.git"
    if File.exist?(git_dir)
      config["repositories"] = [] if config["repositories"].nil?
      config["repositories"].push("name" => name, "path" => path)
      write_config(config)
      puts "Added #{name} repo located #{path}"
    else
      puts "The provided path #{path} does not include a git repository."
    end
  end

  ###
  # Add all repositories from a directory to the config
  ###
  def add_all_repositories
    config = load_config

    directories = Dir.entries(".").select
    directories.each do |repo|
      next if repo == ".grit"

      git_dir = "./" + repo + "/.git"
      next unless File.exist?(git_dir)

      puts "Adding #{repo}"
      config["repositories"].push("name" => repo, "path" => repo)
    end
    write_config(config)
  end

  ###
  # Clean out all missing directories from config
  ###
  def clean_config
    config = load_config

    original_repositories = config["repositories"]
    config["repositories"] = original_repositories.delete_if do |repo|
      git_dir = "./" + repo["path"] + "/.git"
      true if repo["path"].nil? || !File.directory?(repo["path"]) || !File.exist?(git_dir)
    end
    write_config(config)
  end

  ###
  # Get a repository by name
  ###
  def get_repository(name)
    config = load_config
    config["repositories"].detect { |f| f["name"] == name }
  end

  ###
  # Perform a git task on a specific repository
  ###
  def perform_on(repo_name, args)
    repo = get_repository(repo_name)
    args = args.join(" ") unless args.class == String

    if repo.nil? || repo["path"].nil? || !File.exist?(repo["path"])
      puts "Can't find repository: #{repo_name}"
      abort
    end

    Dir.chdir(repo["path"]) do |_d|
      perform(args, repo["name"])
    end
  end

  ###
  # Remove a repository from config by name
  ###
  def remove_repository(name)
    config = load_config

    match = get_repository(name.to_s)
    if match.nil?
      puts "Could not find repository"
    elsif config["repositories"].delete(match)
      write_config(config)
      puts "Removed repository #{name} from grit"
    else
      puts "Unable to remove repository #{name}"
    end
  end

  ###
  # Perform a git task in current working directory.  repo_name is only for output reporting.
  ###
  def perform(git_task, repo_name)
    puts "-" * 80
    puts "# #{repo_name.upcase} -- git #{git_task}" unless repo_name.nil?
    puts `git #{git_task}`
    puts "-" * 80
    puts ""
  end

  ###
  # Perform git task on all repositories in the config list
  ###
  def proceed(args)
    config = load_config

    git_task = args.map { |x| x.include?(" ") ? "\"#{x}\"" : x }.join(" ")

    config["repositories"].each do |repo|
      if repo["path"].nil? || !File.exist?(repo["path"])
        puts "Can't find repository: #{repo["path"]}"
        next
      end

      Dir.chdir(repo["path"]) do |_d|
        perform(git_task, repo["name"])
      end
    end
  end
end

grit = Grit.new

unless ARGV[0] == 'init'
  grit.append_history(ARGV)
end

case ARGV[0]
when "help"
  grit.help
when "history"
  grit.display_history
when "clear-history"
  grit.clear_history
when "init"
  grit.initialize_grit
when /add-(repo|repository)/
  grit.add_repository(ARGV[1..-1])
when "add-all"
  grit.add_all_repositories
when "config"
  grit.display_config
when "clean-config"
  grit.clean_config
when "convert-config"
  grit.convert_config
when "reset"
  grit.reset
when "destroy"
  grit.destroy
when /(rm|remove)-(repo|repository)/
  grit.remove_repository(ARGV[1])
when "on"
  grit.perform_on(ARGV[1], ARGV[2..-1])
when /version|-v|--version/
  puts grit.version
else
  grit.proceed(ARGV)
end
