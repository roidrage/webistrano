class CapfileImporter
  
  IGNORED_VARIABLES = [:logger]
  def initialize
  end

  def run(capfile, options = {:name => "Default", :template => 'rails'})
    filename = "#{RAILS_ROOT}/tmp/webistrano-capfile-import-#{Time.now.to_f.to_s.gsub(".", "-")}.rb"
    File.open(filename, "w") {|f| f.write capfile}
    
    config = Capistrano::Configuration.new
    config.load filename
    
    project = create_project(config, options)
    return project unless project.valid?
    
    stage = project.stages.create(:name => "default")

    add_roles(config, stage)

    add_recipes(config)
    
    add_callback_recipe(config)
    
    project
  ensure
    File.delete(filename) unless filename.nil?
  end
  
  def get_task_source(task)
    "task :#{task.name}, #{task.options.inspect} do #{task.body.source} end\n"
  end
  
  def create_project(config, options)
    project = Project.create(options)

    return project unless project
    
    config.variables.each do |key, value|
      next if value == {} or value.nil? or IGNORED_VARIABLES.include?(key) or value.is_a?(Proc)
      project.configuration_parameters.create(:name => key.to_s, :value => value)
    end
    project
  end
  
  def add_roles(config, stage)
    config.roles.each do |role, hosts|
      hosts.each do |definition|
        host = Host.find_by_name(definition.host)
        host = Host.create(:name => definition.host) unless host
        fresh_role = Role.new(:name => role.to_s, :no_release => definition.options[:no_release] || 0, :no_symlink => definition.options[:no_symlink] || 0, :primary => definition.options[:primary] || 0)
        fresh_role.stage = stage
        fresh_role.host = host
        fresh_role.save
      end
    end
  end
  
  def add_recipes(config)
    config.tasks.each do |name, task|
      body = get_task_source(task)
      Recipe.create(:name => task.desc || unique_recipe_name, :body => body)
    end
    
    config.namespaces.each do |name, namespace|
      tasks_source = ""
      namespace.tasks.each do |name, task|
        tasks_source << get_task_source(task)
      end
      body = "namespace :#{namespace.name.to_s} do\n#{tasks_source}\nend"
      Recipe.create(:name => unique_recipe_name, :body => body)
    end
  end
  
  def add_callback_recipe(config)
    source = ""
    config.callbacks.each do |on, callbacks|
      callbacks.each do |callback|
        if callback.is_a?(Capistrano::TaskCallback)
          if callback.options[:only].nil? and callback.options[:except].nil?
            source << "on :#{on.to_s}, '#{callback.source}'\n"
          elsif !callback.options[:only].nil? and callback.options[:except].nil?
            source << "#{on.to_s} '#{callback.options[:only]}', '#{callback.source}'\n"
          else
            source << "#{on.to_s} '#{callback.source}', #{callback.options.inspect}\n"
          end
        elsif callback.is_a?(Capistrano::ProcCallback)
          source << "#{on.to_s} '#{callback.options[:only]}' do #{callback.source.source} end\n"
        end
      end
    end
    Recipe.create(:name => unique_recipe_name, :body => source) unless source.blank?
  end
  
  def unique_recipe_name
    @recipes ||= Recipe.find(:all)
    @recipe_names ||= @recipes.collect{|recipe| recipe.name}
    index = 1
    name = "Imported Recipe #{index}"
    while @recipe_names.include?(name)
      name = "Imported Recipe #{index += 1}"
    end
    name
  end
end