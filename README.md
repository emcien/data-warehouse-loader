# Emcien Data Warehouse Loader
This sample code is meant to demonstrate the capability of integrating Emcien into your EDW. For more information on this capability, please see http://support.emcien.com/help/data-warehouse-implementation

## How to run the sample code
The sample code is written in Ruby and assumes a MySQL database. 

#### Setup
1. Download and Unzip the source code or clone this repo with GIT
2. With a command prompt, go into the downloaded directory `cd ~/Downloads/data-warehouse-loader-master`
3. Verify you have Ruby 2.0 or greater on your machine with `ruby -v`. If you do not have Ruby 2.0 or greater use please use https://rvm.io/
4. Run `gem install bundler`
5. Run `bundle` This will install required libraries

#### Config
Please edit the config file located in `config/superstore.yml`. This file is used to specify you Emcien server, Emcien API credentials, and your database credientials.

#### Source Data
The Emcien Long Formatted version of Super Store is located here: https://s3.amazonaws.com/emcien-system/assets/superstore.csv

#### Running the Loader Script
Once you have your configuration in place and the source data on the Emcien Server, you are ready to run the load script.

`script/edw-load.rb --config configs/superstore.yml`

