#pivotalreporter.rb
require 'rubygems'
require 'sinatra'
require 'haml'
require 'ruport'
gem 'pivotal-tracker'
require 'pivotal-tracker'
require 'activesupport'

get '/' do
  haml :home
end

post '/projects' do
  http = Net::HTTP.new('www.pivotaltracker.com', 443)
  http.use_ssl = true
  http.start do |http|
    request = Net::HTTP::Get.new('/services/v3/tokens/active')
    request.basic_auth params["username"], params["password"]
    response = http.request(request)
    hash = Hash.from_xml(response.body)
    @token = hash['token']['guid']
  end
  http.start do |http|
    request = Net::HTTP::Get.new('/services/v3/projects')
    request.add_field("X-TrackerToken",@token)
    response = http.request(request)
    hash = Hash.from_xml(response.body)
    projects = hash['projects']
    @projectnames = Array.new
    @projectids = Array.new
    projects.each{|p| @projectnames << p['name']}
    projects.each{|p| @projectids << p['id']}
  end
  haml :projects
end

post '/iterations' do
  #We have the Tracker project ID and API token, now we should allow the user to select the iteration that they want
end

post '/' do
  project = params["project"]
  apikey = params["apikey"]
  @iteration = params["iteration"].to_i
  
  pt = PivotalTracker.new(project, apikey, {:use_ssl => true })
  
  #Last Week (Completed Iteration)
  
  #Features and Bugs
  lw_data = pt.iterations.select{|itr| itr.id == (@iteration - 1)}[0].stories.select {|story| %w(feature bug).include?(story.story_type) }.collect do |story|
    [story.name, story.description, story.story_type, story.estimate, story.url]
  end
  
  lw_data.each{|row| row[0] = "\"#{row[0]}\"\:#{row[4]}"}
  
  lw_table = Table(:data => lw_data, :column_names => ["Name", "Description", "Type", "Points"])
  
  @lw_table_out = clean(lw_table.to_html)
  
  #Chores
  lwc_data = pt.iterations.select{|itr| itr.id == (@iteration -1 )}[0].stories.select {|story| %w(chore).include?(story.story_type) }.collect do |story|
    [story.name, story.description, story.story_type, story.estimate, story.url]
  end
  
  if lwc_data.length != 0 
  
    lwc_data.each{|row| row[0] = "\"#{row[0]}\"\:#{row[4]}"}
  
    lwc_table = Table(:data => lwc_data, :column_names => ["Name", "Description"])
  
    @lwc_table_out = clean(lwc_table.to_html)
  end
  
  #This Week (Planned Iteration)
  tw_data = pt.iterations.select{|itr| itr.id == (@iteration)}[0].stories.select {|story| %w(feature bug chore).include?(story.story_type) }.collect do |story|
    [story.name, story.description, story.story_type, story.estimate, story.url, story.current_state]
  end
  
  #Linkify name column in textile
  tw_data.each{|row| row[0] = "\"#{row[0]}\"\:#{row[4]}"}
  
  #Add note to description if story is already started
  tw_data.each{|row| if row[5] 
      row[1] = "\*#{row[5]}\*<br \\>#{row[1]}"
    end }
  
  tw_table = Table(:data => tw_data, :column_names => ["Name", "Description", "Type", "Points"])
  
  @tw_table_out = clean(tw_table.to_html)    
  
  #New Stories
  ns_data = pt.stories.select{|story| story.created_at > (DateTime.now - 7.days)}.select {|story| %w(feature bug).include?(story.story_type) }.collect do |story|
    [story.name, story.description, story.story_type, story.estimate, story.url]
  end
  
  ns_data.each{|row| row[0] = "\"#{row[0]}\"\:#{row[4]}"}
  
  ns_table = Table(:data => ns_data, :column_names => ["Name", "Description", "Type", "Points"])
  
  @ns_table_out = clean(ns_table.to_html)

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
      = @projectnames.each_index do |p|
        %option{:value => "#{@projectids[p]}"} #{@projectnames[p]}
    %input{:type => "hidden", :name => "token", :value => "#{@token}"}

  %p
    %input{:type => "submit", :value => "submit"}

  