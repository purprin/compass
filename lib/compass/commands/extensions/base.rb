require "net/http"
require "uri"
require 'rubygems/dependency_installer'
begin 
  require 'json'
rescue LoadError
  require 'json/pure'
end
module Compass
  module Commands
    module Extensions
      class Base
        HOST = "http://localhost:3000"
        class << self
          include Compass::Actions
          
          def actions
            a = Object.dup
            a.send(:include, Compass::Actions)
            a.class_eval do
              def working_path
                ''
              end
              def options
                {}
              end
            end
            a.new
          end
          
          def load_json_from_repo
            uri = URI.parse "#{HOST}/extensions.json"
            http = Net::HTTP.new(uri.host, uri.port)
            response = http.request(Net::HTTP::Get.new(uri.request_uri))
            response.body
          end
          
          def parse_json(data)
            JSON.parse data
          end
          
          def extensions
            json =load_json_from_repo
            parse_json(json)
          end
          
          def list
            extensions.each do |ext|
              print_extension_info(ext)
            end
          end
          
          def search(extension)
            print "Searching for: #{extension}"
            results = extensions.map {|e| e if e['name'].downcase =~ %r{#{extension}}}.compact
            if results.empty?
              print "No Exensions found matching: #{extension}"
              return
            end
            results.each do |ext|
              print_extension_info(ext)
            end
          end
          
          
          def find_extension(extension_name)
            extensions.detect { |ext| ext if ext['name'].downcase == extension_name.downcase}
          end
          
          def not_an_extension(ext)
            print "Extension: #{ext} not found"
            exit(-1)
          end
          
          def get_deps(ext)
            ext['ruby_gem_cache']['dependencies']['runtime'].map{|dep| "#{dep['name']} (#{dep['requirements']})" unless dep['name'].downcase == 'compass'}.compact.join(', ')
          end
          
          def version(ext)
            ext['ruby_gem_cache']['version']
          end
          
          def inject_into_config_file(extension_name, version)
            #do what it says damnit
          end
          
          def install_to_gemfile(extension)
            ext = find_extension(extension)
            gem_string = "  gem '#{ext['ruby_gem_cache']['name']}', '#{version(ext)}'\n"
            gemfile = File.join(Compass.configuration.project_path, 'Gemfile')
            if File.read(gemfile).include?("group :assets do")
              actions.inject_into_file(gemfile, gem_string, :after, "group :assets do\n")
            else
              actions.inject_at_bottom(gemfile, "\ngroup :assets do\n#{gem_string}end\n")
            end
          end
          
          def install(extension)
            if File.exists?(File.join(Compass.configuration.project_path, 'Gemfile'))
              print "Installing gem to your Gemfile make sure to run bundle install"
              install_to_gemfile(extension)
            else
              install_from_gem(extension)
            end
          end
          
          def install_from_gem(extension)
            ext = find_extension(extension)
            not_an_extension(extension) unless ext
            deps = get_deps(ext)
            installer = Gem::DependencyInstaller.new
            buffer = []
            buffer << "Installing: #{extension} (#{version(ext)})"
            unless deps.empty?
              buffer << " and dependencies #{deps}"
            end
            print buffer.join
            installer.install(ext['ruby_gem_cache']['name'], version(ext))
            inject_into_config_file(extension, version(ext))
          rescue Gem::InstallError
            not_an_extension
          end
          
          def remove(extension)
            
          end
          
          
          def print_extension_info(ext)
            print "#{ext['name']} (#{version(ext)})"
          end
          
          
          def print(string)
            puts string
          end
        
        end      
      end
    end
  end
end