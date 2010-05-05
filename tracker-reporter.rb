#tracker-reporter.rb
require 'rubygems'
require 'sinatra'
require 'haml'
require 'ruport'
gem 'pivotal-tracker'
require 'pivotal-tracker'
gem 'activesupport', '2.3.5'

enable :inline_templates

before do
  if request.cookies["token"].nil? && request.path_info != '/' && request.path_info != '/login'
    redirect '/'
  end
end

get '/' do
  haml :home
end

get '/login' do
  haml :login
end

post '/login' do
  @token = PivotalTracker::Client.token(params["username"], params["password"])
  response.set_cookie("username", params["username"])
  response.set_cookie("token", @token)
  redirect '/projects'
end

get '/logout' do
  response.delete_cookie("username")
  response.delete_cookie("token")
  redirect '/'
end

get '/projects' do
  @token = PivotalTracker::Client.token = request.cookies["token"]
  PivotalTracker::Client.use_ssl = true
  @projects = PivotalTracker::Project.all
  haml :projects
end

post '/projects' do
  @project = params["project"]
  projectURL = '/projects/'<< @project << '/iterations'
  redirect projectURL
end

get '/projects/:project_id/iterations' do
  PivotalTracker::Client.token = request.cookies["token"]
  PivotalTracker::Client.use_ssl = true
  @project = params["project_id"].to_i
  @proj = PivotalTracker::Project.find(@project)
  @iterations = @proj.iterations.all
  @postUrl = request.path_info
  
  #Project Report
  @projectReportUrl = '/projects/' << params["project_id"] << '/report'
  
  haml :iterations
end

post '/projects/:project_id/iterations' do
  reportURL = '/projects/' << params["project_id"] << '/iterations/' << params["iteration"] << '/report'
  redirect reportURL
end

get '/projects/:project_id/report' do
  project = params["project_id"].to_i

  PivotalTracker::Client.token = request.cookies["token"]
  PivotalTracker::Client.use_ssl = true

  @proj = PivotalTracker::Project.find(project)
  
  #Get last 10 done iterations

#  Pivotal Tracker gem needs to be updated  
#  completedIterations = @proj.iterations.done(:offset => '-10')

  #find the current iteration
  currentIterationID = 0
  
  @proj.iterations.all.each do |itr|
    if itr.finish > DateTime.now && itr.start < DateTime.now
      currentIterationID = itr.id
      break
    end
  end

  estimateCounts = Hash.new
  estimateCountsTable = Table(:column_names => %w[iteration features chores bugs])
  
  
  @proj.iterations.all.each do |itr|
    if ((itr.id >= (currentIterationID - 10)) && (itr.id < (currentIterationID)))
      features = chores = bugs = 0
      itr.stories.each do |story|
        if story.story_type == "feature"
          features += story.estimate
        elsif story.story_type == "chore"
          chores += story.estimate
        elsif story.story_type == "bug"
          bugs += story.estimate
        end
      end
      estimateCountsTable << [itr.id, features, chores, bugs]
    end
  end
  
  estimateCountsTable.sort_rows_by!(["iteration"])
  
  @estimateCountsTableOut = estimateCountsTable.to_html
  
  haml :projectReport
end

get '/projects/:project_id/iterations/:iteration/report' do
  
  project = params["project_id"].to_i
  iteration = params["iteration"].to_i
  
  PivotalTracker::Client.token = request.cookies["token"]
  PivotalTracker::Client.use_ssl = true
  
  @proj = PivotalTracker::Project.find(project)
  @itr = @proj.iterations.find(iteration)
  
=begin
  #ALL
  all_data = @itr.stories.select {|story| %w(feature bug chore).include?(story.story_type) }.collect do |story|
    [story.name, story.description, story.story_type, story.estimate, story.url]
  end
  
  all_data.each{|row| row[0] = "\"#{row[0]}\"\:#{row[4]}"}
  
  all_table = Table(:data => all_data, :column_names => ["Name", "Description", "Type", "Points"])
  
  @all_table_out = clean(all_table.to_html)
=end
  
  #Features
  feat_data = @itr.stories.select {|story| %w(feature).include?(story.story_type) }.collect do |story|
    [story.name, story.description, story.estimate, story.url]
  end
  
  feat_data.each{|row| row[0] = "\"#{row[0]}\"\:#{row[3]}"}
  
  feat_table = Table(:data => feat_data, :column_names => ["Name", "Description", "Points"])
  
  feat_table.sort_rows_by!("Points", :order => :descending )
  
  @feat_table_out = clean(feat_table.to_html)
  
  #Chores
  chore_data = @itr.stories.select {|story| %w(chore).include?(story.story_type) }.collect do |story|
    [story.name, story.description, story.url]
  end
  
  chore_data.each{|row| row[0] = "\"#{row[0]}\"\:#{row[2]}"}
  
  chore_table = Table(:data => chore_data, :column_names => ["Name", "Description"])
  
  @chore_table_out = clean(chore_table.to_html)
  
  #Bugs
  bug_data = @itr.stories.select {|story| %w(bug).include?(story.story_type) }.collect do |story|
    [story.name, story.description, story.url]
  end
  
  bug_data.each{|row| row[0] = "\"#{row[0]}\"\:#{row[2]}"}
  
  bug_table = Table(:data => bug_data, :column_names => ["Name", "Description"])
  
  @bug_table_out = clean(bug_table.to_html)
  
  haml :report
end

helpers do
  def clean(output)
=begin    
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
=end    
    output = output.gsub(/<td>-1<\/td>/,"<td>??</td>")
    output = output.gsub(/<td>0<\/td>/,"<td>n/a</td>")
  end
  
  def loggedin?
    !request.cookies["token"].nil? 
  end
  
  def partial(page, options={})
    haml page, options.merge!(:layout => false)
  end
end
    
__END__
@@ home
%h1 Tracker Reporter
%p
  Tracker Reporter is used to generate HTML reports from 
  %a{:href=>"http://www.pivotaltracker.com"}Pivotal Tracker

@@ login
%form{:method => "post", :action => "/login"}
  %p
    Username
    %input{:type => "text", :name => "username"}
  %p
    Password
    %input{:type => "password", :name => "password"}
  %p
    %input{:type => "submit", :value => "submit"}

@@ projects
%form{:method => "post", :action => "/projects"}
  %p
    Projects
    %select{:name => "project"}
      = @projects.each do |p|
        %option{:value => "#{p.id}"} #{p.name}

  %p
    %input{:type => "submit", :value => "submit"}

@@ iterations
%p
  %a{:href => "#{@projectReportUrl}"}Project Report
%form{:method => "post", :action => "#{@postUrl}"}
  %p 
    Iterations
    %select{:name => "iteration"}
      = @iterations.each do |i|
        %option{:value => "#{i.number}"} #{i.number} - #{i.finish.strftime("%m/%d/%Y")} 

  %p
    %input{:type => "submit", :value => "submit"}
       
@@ projectReport
#{@estimateCountsTableOut}