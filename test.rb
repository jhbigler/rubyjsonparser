#!/usr/bin/env ruby

require_relative './jsonparser'
require 'pp'

str = File.read ARGV.first
json = JSONParser.parse str

PP.pp json, $>, 40