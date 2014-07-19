# Ec2l

[![Build Status](https://travis-ci.org/yazgoo/ec2l.svg?branch=master)](https://travis-ci.org/yazgoo/ec2l)
[![Test Coverage](https://codeclimate.com/github/yazgoo/ec2l/coverage.png)](https://codeclimate.com/github/yazgoo/ec2l)
[![Code Climate](https://codeclimate.com/github/yazgoo/ec2l.png)](https://codeclimate.com/github/yazgoo/ec2l)
[![Inline docs](http://inch-ci.org/github/yazgoo/ec2l.png?branch=master)](http://inch-ci.org/github/yazgoo/ec2l)
[![Gem Version](https://badge.fury.io/rb/ec2l.svg)](http://badge.fury.io/rb/ec2l)


Ec2l aims to provide an efficient low level UI to EC2.

## Installation

Add this line to your application's Gemfile:

    gem 'ec2l'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ec2l

## Usage

You can call public client methods directly from the ec2l command line,
though a better way is to use the shell, which relies on pry:

    $ ec2l shell


```ruby
...
[2] pry(#<Ec2l::Client>)> h # print help
Usage: action parameters...
available actions:
[
    [0]            associate(address, id) Ec2l::Client
    [1]                  ins()            Ec2l::Client
...
[2] pry(#<Ec2l::Client>)> show-doc ins
...
Public: return virtual machines instances with few details

Examples

  ins[0]
      => {:instanceId=>"i-deadbeef", :instanceState=>
                      {"code"=>"16", "name"=>"running"},
           :ipAddress=>"10.1.1.2", :tagSet=>{:k=>"v"}}

Returns an array with instanceId, ipAddress, tagSet, instanceState in a hash
[7] pry(#<Ec2l::Client>)> ins
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/ec2l/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
