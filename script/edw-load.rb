#!/usr/bin/env ruby
require_relative '../lib/lib.rb'
require "colorize"
require "colorized_string"
require "tty-spinner"

# SETUP
@opts = Trollop::options do
  opt :config, "Path to config file", short: "-c", type: :string
end

Trollop::die("Config file must be specified") unless @opts[:config]
Trollop::die("Config file must exist") unless File.exist? @opts[:config]
RbConfig.read(File.expand_path(@opts[:config]))

def die(msg)
  warn("#{msg} ... :(")
  exit(1)
end

puts "\nWelcome to " + ColorizedString.new("Emcien Data Warehouse Loader\n").colorize(:green)
puts "Your Emcien server is: " + ColorizedString.new(RbConfig.patterns_url).colorize(:light_green)
puts "and you are loading data into the database: " + ColorizedString.new(RbConfig.database['name']).colorize(:light_green)


# BANDING NUMERIC DATA
puts "\nStarting Emcien Banding".light_yellow
puts "Section 1 of 6"
banding_spinner = TTY::Spinner.new(":spinner Banding ... ", format: :dots)
banding_spinner.auto_spin

# POST TO API
create_bandit_run = API.post("/api/v1/runs", RbConfig.bandit_params.to_h)
die(create_bandit_run) unless (create_bandit_run.code == 202)

bandit_run_id = create_bandit_run["data"]["id"]
bandit_run = API.get("/api/v1/runs/#{bandit_run_id}")
die(bandit_run) unless (bandit_run.code == 200)

# CHECK STATUS OF RUN
while (bandit_run.code == 200 && bandit_run["data"]["state"] !~ /ready/)
  puts "#{bandit_run["data"]["state"]} ... Run ID: #{bandit_run_id}"
  sleep(10)
  bandit_run = API.get("/api/v1/runs/#{bandit_run_id}")
end

breaks_text = HTTParty.get("https://#{bandit_run["links"]["breaks_file"]}", headers: API.default_get_headers)

banding_spinner.success
puts "Success! Data is Banded".colorize(:light_yellow)


# BUILDING RULES
puts "\n\nBuilding Prediction Rules".green
puts "Starting Section 2 of 6"

rules_spinner = TTY::Spinner.new(":spinner Rules ... ", format: :dots)
rules_spinner.auto_spin

params_with_breaks = RbConfig.report_params.to_h
params_with_breaks["custom_breaks"] = breaks_text.body

create_report = API.post("/api/v1/reports", params_with_breaks)
die(create_report) unless (create_report.code == 202)

report_id = create_report["data"]["id"]
report = API.get("/api/v1/reports/#{report_id}")
die(report) unless (report.code == 200)

while (report.code == 200 && report["data"]["state"] !~ /ready/)
  if report["data"]["state"] =~ /failed/
    die("Failed ... #{report["data"]["state"]}")
  end

  puts "#{report['data']['state']}"
  sleep(10)
  report = API.get("/api/v1/reports/#{report_id}")
end

rules_spinner.success
puts "Success! Rules are Created".colorize(:green)
puts "Rules: #{report["data"]["name"]} is #{report["data"]["state"]}"



# SETUP DATABASE
puts "\n\nLoading Report Data into Data Warehouse".cyan
puts "Starting Section 3 of 6"

db = RbConfig.database
client = Mysql2::Client.new(host: db.host, username: db.user, password: db.password)
client.select_db(db.name)

sql = client.prepare("INSERT INTO #{db.emcien_analyses_table["name"]} VALUES (NULL,?,?,NOW(),?)")
result = sql.execute(report['data']['id'], report['data']['name'], report['data']['state'])

puts "✔ Success! Report Saved".cyan



# LOAD RULES
puts "\n\nLoading Rules into Data Warehouse".magenta
puts "Starting Section 4 of 6"

rules_load_spinner = TTY::Spinner.new(":spinner Loading ... ", format: :dots)
rules_load_spinner.auto_spin

$page = 1
$total_pages = 2

while $page < $total_pages + 1 do
  # Request a page of Rules
  $rules = API.get("/api/v1/reports/#{report_id}/rules?page=#{$page}&size=100&filter[size]=1")

  # Iterate through each rule
  $rule_idx = 0
  $total_rules = 1
  sql = client.prepare("INSERT INTO #{db.emcien_rules_table["name"]} VALUES (NULL,?,?,?,?,?,?,?,?)")

  while $rule_idx < $total_rules do
    rule = $rules['data'][$rule_idx]

    # Format Value for BI Report
    name = rule['item_names'][1..-2]
    category = rule['category_names'][1..-2]
    frequency = rule['cluster_frequency'].to_i
    lift = rule['lift']
    outcome = rule['outcome_item_name']
    conditional_probability = rule['conditional_probability']

    result = sql.execute(name, 1, category, frequency, lift, outcome, report_id, conditional_probability)

    $total_rules = $rules['meta']['records_on_page']
    $total_pages = $rules['meta']['pages_total']
    $rule_idx += 1

    puts " Rule ... #{$page} of #{$total_pages} API Requests" if $rule_idx.to_i % 100 == 0
  end

  $page += 1
end

rules_load_spinner.success
puts "Success! Rules are loaded into the Data Warehouse".colorize(:magenta)



# BUILD PRODUCT RECOMMENDATIONS
puts "\n\nBuilding Recommendations".green
puts "Starting Section 5 of 6"

recommendations_spinner = TTY::Spinner.new(":spinner Recommendations ... ", format: :dots)
recommendations_spinner.auto_spin

affinity_params = RbConfig.affinity_params.to_h
affinity_params["custom_breaks"] = breaks_text.body

create_report = API.post("/api/v1/reports", affinity_params)
die(create_report) unless (create_report.code == 202)

report_id = create_report["data"]["id"]
report = API.get("/api/v1/reports/#{report_id}")
die(report) unless (report.code == 200)

while (report.code == 200 && report["data"]["state"] !~ /ready/)
  if report["data"]["state"] =~ /failed/
    die("Failed ... #{report["data"]["state"]}")
  end

  warn("#{report["data"]["state"]}")
  sleep(10)
  report = API.get("/api/v1/reports/#{report_id}")
end

recommendations_spinner.success
puts "Success! Recommendations are Created".colorize(:green)



# LOAD AFFINITIES
puts "\n\nLoading Recommendations into Data Warehouse".magenta
puts "Starting Section 6 of 6"

recommendations_load_spinner = TTY::Spinner.new(":spinner Loading ... ", format: :dots)
recommendations_load_spinner.auto_spin

$recommendation_page = 1
$total_recommendation_pages = 2

while $recommendation_page < $total_recommendation_pages + 1 do
  # Request a page of Rules
  $recommendations = API.get("/api/v1/reports/#{report_id}/clusters?page=#{$recommendation_page}&size=100&filter[size]=2")

  # Iterate through each affinity
  $recommendations_idx = 0
  $total_recommendations = 1

  sql = client.prepare("INSERT INTO #{db.emcien_recommendations_table["name"]} VALUES (NULL,?,?,?,?,?)")

  while $recommendations_idx < $total_recommendations do
    $recommendation = $recommendations['data'][$recommendations_idx]

    $names = $recommendation['item_names'].split("|")
    $ids = $recommendation['item_ids'].split("|")
    $strength = $recommendation['strength']
    $recommendation_frequency = $recommendation['count']

    # Product A Recommendation
    $product_a = API.get("/api/v1/reports/#{report_id}/items/#{$ids[1]}")
    $product_a_frequency = $product_a['data']['transaction_count']
    $product_a_cprob = ($product_a_frequency.to_f / $product_a_frequency.to_f).round(4)
    result = sql.execute($names[1], $names[2], $strength, $recommendation_frequency, $product_a_cprob)

    #Product B Recommendation
    $product_b = API.get("/api/v1/reports/#{report_id}/items/#{$ids[2]}")
    $product_b_frequency = $product_b['data']['transaction_count']
    $product_b_cprob = ($product_b_frequency.to_f / $product_b_frequency.to_f).round(4)
    result = sql.execute($names[2], $names[1], $strength, $recommendation_frequency, $product_b_cprob)

    $total_recommendations = $recommendations['meta']['records_on_page']
    $total_recommendation_pages = $recommendations['meta']['pages_total']
    $recommendations_idx += 1

    puts " Recommendation ... #{$recommendation_page} of #{$total_recommendation_pages} API Requests" if $recommendations_idx.to_i % 100 == 0
  end

  $recommendation_page += 1
end

recommendations_load_spinner.success
puts "Success! Recommendations are Loaded into Data Warehouse".colorize(:magenta)

puts "\n\n\nDone!".colorize(:magenta)
puts "All Data is loaded into the Data Warehouse 😀 😀 😀\n\n\n"
