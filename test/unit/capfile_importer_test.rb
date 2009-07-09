require File.dirname(__FILE__) + '/../test_helper'

class CapfileImporterTest < Test::Unit::TestCase
  def setup
    @importer = CapfileImporter.new
    Host.delete_all
    Project.delete_all
    Role.delete_all
    ConfigurationParameter.delete_all
    ProjectConfiguration.delete_all
    Recipe.delete_all
  end
  
  def test_should_create_a_project
    assert_equal Project, @importer.run("set :repository, \"http://path.to/my/repo\"").class
  end
  
  def test_should_set_a_configuration_option
    assert_equal 13, @importer.run("set :repository, \"http://path.to/my/repo\"").configuration_parameters.size
  end
  
  def test_should_skip_block_configuration_options
    assert_equal 12, @importer.run("set(:repository) { 'repository' }").configuration_parameters.size
  end
  
  def test_shop_create_a_default_stage
    project = @importer.run("set(:reposiroty, 'hossa')")
    assert_equal 1, project.stages.size
    assert_equal 'default', project.stages.first.name
  end
  
  def test_should_create_hosts_for_each_role
    project = @importer.run("role :www, 'my.host'")
    assert_equal 1, Host.count
    assert_equal 'my.host', Host.first.name
  end
  
  def test_should_create_role
    project = @importer.run("role :www, 'my.host'")
    assert_equal 1, Role.count
    assert_equal 'www', Role.first.name
  end
  
  def test_should_create_a_recipe_for_a_task
    project = @importer.run <<-END
desc "Chunky bacon!"
task :do_something do
  puts "something else"
end
END
    assert_equal 1, Recipe.count
    assert_equal "Chunky bacon!", Recipe.first.name
  end
  
  def test_should_create_a_recipe_for_a_namespace_and_its_tasks
    project = @importer.run <<-END
namespace :chunky do
  desc "Chunky bacon!"
  task :bacon do
    puts "something else"
  end
  
  desc "Chunky bacon!"
  task :salami do
    puts "salami!"
  end
end
END
    assert_equal 1, Recipe.count
    assert Recipe.first.name.starts_with?("Imported Recipe")
  end
  
  def test_should_create_a_recipe_for_the_callbacks
    project = @importer.run <<-END
before "deploy", "deploy:restart"
after "deploy", "deploy:restart"
    END
    assert_equal 1, Recipe.count
    assert_equal "Imported Recipe 1", Recipe.first.name
  end
  
  def test_should_generate_a_block_callback_if_block_is_specified
    project = @importer.run <<-END
before "deploy" do
  puts "it's a block!"
end
    END
    assert_equal "before 'deploy' do \n puts \"it's a block!\"\n end\n", Recipe.first.body
  end
  
  def test_should_generate_a_callback_for_each_arg
    project = @importer.run <<-END
before "deploy", "do:this", "then:this"
    END
    assert_equal "before 'deploy', 'do:this'\nbefore 'deploy', 'then:this'\n", Recipe.first.body
  end
  
  def test_should_generate_global_callback
    project = @importer.run <<-END
on :after, "do:it"
    END
    assert_equal "on :after, 'do:it'\n", Recipe.first.body
  end
  
  def test_should_return_project_if_save_fails
    project = @importer.run 'on :after, "do:it"', :name => nil, :description => nil
    assert project.new_record?
  end
end