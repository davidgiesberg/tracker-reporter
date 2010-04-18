#tracker-reporter.rb
require 'rubygems'
require 'sinatra'
require 'haml'
require 'ruport'
gem 'pivotal-tracker'
require 'pivotal-tracker'
gem 'activesupport', '2.3.5'

get '/' do
  haml :home
end

post '/projects' do
  @token = PivotalTracker::Client.token(params["username"], params["password"])
  PivotalTracker::Client.use_ssl
  @projects = PivotalTracker::Project.all
  haml :projects
end

post '/iterations' do
  @project = params["project"].to_i
  @token = PivotalTracker::Client.token = params["token"]
  PivotalTracker::Client.use_ssl = true
  @proj = PivotalTracker::Project.find(@project)
  @iterations = @proj.iterations.all
  haml :iterations
end

post '/report' do
  project = params["project"].to_i
  PivotalTracker::Client.token = params["token"]
  PivotalTracker::Client.use_ssl = true
  @proj = PivotalTracker::Project.find(project)
  iteration = params["iteration"].to_i
  @itr = @proj.iterations.find(iteration)
  
  #ALL
  all_data = @itr.stories.select {|story| %w(feature bug chore).include?(story.story_type) }.collect do |story|
    [story.name, story.description, story.story_type, story.estimate, story.url]
  end
  
  all_data.each{|row| row[0] = "\"#{row[0]}\"\:#{row[4]}"}
  
  all_table = Table(:data => all_data, :column_names => ["Name", "Description", "Type", "Points"])
  
  @all_table_out = clean(all_table.to_html)
  
  #Features
  feat_data = @itr.stories.select {|story| %w(feature).include?(story.story_type) }.collect do |story|
    [story.name, story.description, story.story_type, story.estimate, story.url]
  end
  
  feat_data.each{|row| row[0] = "\"#{row[0]}\"\:#{row[4]}"}
  
  feat_table = Table(:data => feat_data, :column_names => ["Name", "Description", "Type", "Points"])
  
  @feat_table_out = clean(feat_table.to_html)
  
  #Chores
  chore_data = @itr.stories.select {|story| %w(chore).include?(story.story_type) }.collect do |story|
    [story.name, story.description, story.story_type, story.estimate, story.url]
  end
  
  chore_data.each{|row| row[0] = "\"#{row[0]}\"\:#{row[4]}"}
  
  chore_table = Table(:data => chore_data, :column_names => ["Name", "Description", "Type", "Points"])
  
  @chore_table_out = clean(chore_table.to_html)
  
  #Bugs
  bug_data = @itr.stories.select {|story| %w(bug).include?(story.story_type) }.collect do |story|
    [story.name, story.description, story.story_type, story.estimate, story.url]
  end
  
  bug_data.each{|row| row[0] = "\"#{row[0]}\"\:#{row[4]}"}
  
  bug_table = Table(:data => bug_data, :column_names => ["Name", "Description", "Type", "Points"])
  
  @bug_table_out = clean(bug_table.to_html)
  
  haml :report
end

helpers do
  def clean(output)
    output = output.gsub(/<p>accepted<\/p>/,"<h3>Accepted</h3>")
    output = output.gsub(/<p>delivered<\/p>/,"<h3>Under Review</h3>")
    output = output.gsub(/<p>started<\/p>/,"<h3>In Progress</h3>")
    output = output.gsub(/<p>unstarted<\/p>/,"<h3>Not Started</h3>")

    output = output.gsub(/<p>feature<\/p>/,"<h3>Features</h3>")
    output = output.gsub(/<p>bug<\/p>/,"<h3>Bugs</h3>")
    output = output.gsub(/<p>chore<\/p>/,"<h3>Chores</h3>")
    output = output.gsub(/<p>release<\/p>/,"<h3>Releases</h3>")

    output = output.gsub(/<td>feature<\/td>/,"<td><img src=\"http://pivotaltracker.com/images/v3/icons/stories_view/feature_icon.png\" alt=\"feature\"><\/img>")
    output = output.gsub(/<td>chore<\/td>/,"<td><img src=\"http://pivotaltracker.com/images/v3/icons/stories_view/chore_icon.png\" alt=\"feature\"><\/img>")
    output = output.gsub(/<td>bug<\/td>/,"<td><img src=\"http://pivotaltracker.com/images/v3/icons/stories_view/bug_icon.png\" alt=\"feature\"><\/img>")
    output = output.gsub(/<td>release<\/td>/,"<td><img src=\"http://pivotaltracker.com/images/v3/icons/stories_view/release_icon.png\" alt=\"feature\"><\/img>")
    
    output = output.gsub(/<td>-1<\/td>/,"<td>??</td>")
    output = output.gsub(/<td>0<\/td>/,"<td>n/a</td>")
  end
  
  def partial(page, options={})
    haml page, options.merge!(:layout => false)
  end
end
    
__END__
@@ home
%form{:method => "post", :action => "/projects"}
  %p
    Username
    %input{:type => "text", :name => "username"}
  %p
    Password
    %input{:type => "password", :name => "password"}
  %p
    %input{:type => "submit", :value => "submit"}

@@ projects
%form{:method => "post", :action => "/iterations"}
  %p
    Projects
    %select{:name => "project"}
      = @projects.each do |p|
        %option{:value => "#{p.id}"} #{p.name}
    %input{:type => "hidden", :name => "token", :value => "#{@token}"}

  %p
    %input{:type => "submit", :value => "submit"}

@@ iterations
%form{:method => "post", :action => "/report"}
  %p 
    Iterations
    %select{:name => "iteration"}
      = @iterations.each do |i|
        %option{:value => "#{i.number}"} #{i.number} - #{i.finish.strftime("%m/%d/%Y")} 
    %input{:type => "hidden", :name => "project", :value=> "#{@project}"}
    %input{:type => "hidden", :name => "token", :value => "#{@token}"}

  %p
    %input{:type => "submit", :value => "submit"}
       