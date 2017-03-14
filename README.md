Knife Search Wrapper
====================

A knife plugin that is almost a direct copy of knife search but with the -o / --sort option dealt with on the client side.

## Background

Today I have attempted to run a knife search specifying sort criteria, unfortunately the data didn't come out in the desired order!

Is this a bug? Perhaps but I couldn't get the sort option to work, is it related to this https://github.com/chef/chef-server/issues/8

## Solution

My first thoughts were to wrap the knife search functionality and just call the methods I want to retrieve the data, perform a client side sort and then display the result, something like below

```ruby
def run
  srch = Chef::Knife::Search.new
  srch.name_args = name_args
  srch.config = config
  results = srch.<methods I want>
```

Unfortunately virtually ALL of the code for knife search is in the run method, the method is too big to monkey patch so I've copied the code to add some sorting capability.

The code in this wrapper is clunky because the search mechanism can return back a Chef:: object, the resulting Chef:: objects are quite large and sorting them directly may result in OOM errors - although in most cases the memory issues I've encountered are caused by converting "node" data to JSON or YAML.

The plugin is called knife search wrapper but should be able to co-exist with the normal knife search.

## Requirements

You will need 
* Ruby installed and Chef 

or preferably 

* ChefDK

#### Building

Build and install the gem with 
````
rake install
````

Check with

````
gem list knife
````

## Usage

The knife_search_wrapper gem works in the same way as knife search (at time of writing, March 2017)

Typical usage (see: https://docs.chef.io/knife_search.html)

````
knife search wrapper node "platform:centos" -a <attribute> -a <attribute> -o <attribute>
knife search wrapper node "platform:centos" -o <attribute>
knife search wrapper node "platform:centos" -o <attribute> -F pp
knife search wrapper environment "name:*" -a default_attributes.<attributes> -o default_attributes.<attribute>
knife search wrapper environment "name:*" -o default_attributes.<attribute>
````

Examples

````
knife search wrapper node "platform:centos" -a cookbooks.chef-sugar.version -o cookbooks.chef-sugar.version
````

#### Limitations
- Client side sort
- If using -a for attribute then you must include the sort attribute must be included in the -a list
- Sort is based on strings, does not sort or know about numeric fields
- Does not consider pagination, assumes all results returned
    - To be fair I've never got the -b ROW, --start ROW and -R INT, --rows INT parameters to work
- Does not work with formats of YAML or JSON (i.e. command line options of -F yaml -F json)

#### Ruby versions

Works with Ruby versions
* 2.3.1p112 (2016-04-26 revision 54768) [i386-mingw32]
