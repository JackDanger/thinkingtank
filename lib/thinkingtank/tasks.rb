# Load init for Rails 2, since it directly loads this file
require 'thinkingtank/init'

def load_models
    app_root = ThinkingTank::Configuration.instance.app_root
    dirs = ["#{app_root}/app/models/"] + Dir.glob("#{app_root}/vendor/plugins/*/app/models/")
    
    dirs.each do |base|
        Dir["#{base}**/*.rb"].each do |file|
            model_name = file.gsub(/^#{base}([\w_\/\\]+)\.rb/, '\1')

            next if model_name.nil?
            next if ::ActiveRecord::Base.send(:subclasses).detect { |model|
                model.name == model_name
            }

            begin
                model_name.camelize.constantize
            rescue LoadError
                model_name.gsub!(/.*[\/\\]/, '').nil? ? next : retry
            rescue NameError
                next
            rescue StandardError
                STDERR.puts "Warning: Error loading #{file}"
            end
        end
    end
end

def reindex_models
    it = ThinkingTank::Configuration.instance.client
    if it.nil?
        puts "!!! Couldn't create a client. Does config/indextank.yml have the correct info?"
        return false
    end

    if it.exists? and it.code
        # Check for code because it.exists? may return true for a
        # nonexistent index
        puts "Deleting existing index"
        it.delete_index()
    end
    puts "Creating a new empty index"
    it.create_index()
    puts "Waiting for the index to be ready (this might take a while)"
    while not it.running?
        print "."
        STDOUT.flush
        sleep 0.5
    end
    print "\n"
    STDOUT.flush


    Object.subclasses_of(ActiveRecord::Base).each do |klass|
        reindex klass if klass.is_indexable?
    end
end

def reindex(klass)
    klass.find(:all).each do |obj|
        puts "re-indexing #{obj.class.name}:#{obj.id}"
        obj.update_index
    end
end

namespace :indextank do
  # MUST have a description for it to show up in rake -T!
    desc "Reindex all models. This deletes and recreates the index."
    task :reindex => :environment do
        load_models
        reindex_models
    end
end

namespace :it do
    desc "An alias for indextank:reindex"
    task :reindex => "indextank:reindex"
end
