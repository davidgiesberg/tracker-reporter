Given /^I am viewing "(.+)"$/ do |url|
  visit(url)
end

Then /^I should see '(.*)'$/ do |text|
  body.should match(/#{text}/m)
end

Then /^I should see "([^\"]*)"$/ do |text|
  body.should match(/#{text}/m)
end
