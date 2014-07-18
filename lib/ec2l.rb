require "ec2l/version"
require 'base64'
require 'awesome_print'
require 'pry'
module Ec2l
    class Client
        def instances keep = ["instanceId", "ipAddress", "groups",
                              "launchType", "instanceType", "tagSet"]
            @ec2.describe_instances.reservationSet.item.collect do |item|
                group = item.groupSet if keep.include? "groups"
                item = item.instancesSet.item[0].reject{|k, v| not keep.include? k}
                item["groups"] = group.item.map{|x| x.groupId } if not group.nil?
                item["tagSet"] = to_hash(item["tagSet"].item) if item["tagSet"]
                Hash[item.map { |k, v| [k.to_sym, v] }]
            end
        end
        def instance(id) @ec2.describe_instances(instance_id: id) end
        def associate address, id
            @ec2.associate_address public_ip: address, instance_id: id
        end
        def sgs
            @ec2.describe_security_groups.securityGroupInfo.item.collect do |item|
                item.reject { |k, v| not ["groupName", "ownerId"].include? k }
            end
        end
        def i() instances ["instanceId", "ipAddress", "tagSet", "instanceState"] end
        def log id
            puts Base64.decode64 @ec2.get_console_output(instance_id: id)["output"]
        end
        def terminate(id) @ec2.terminate_instances(instance_id: id) end
        def shell() binding.pry end
        def update_configuration creds = nil
            puts "Will try and update configuration in #{@conf}"
            creds = read_credentials if creds.nil?
            File.open(@conf, "w") do |f|
                ["access key", "secret access key",
                 "entry point (default being https://aws.amazon.com if blank)"
                ].each_with_index do |prompt, i|
                    printf "#{prompt} (#{creds.size > i ? creds[i]:""}): "
                    line = $stdin.gets.chomp
                    line = creds[i] if line.empty? and creds.size > i
                    f.puts line if not line.empty?
                end
            end
        end
        def read_credentials
            creds = []
            File.open(@conf) { |f| f.each_line { |l| creds << l.chomp } } if File.exists?(@conf)
            creds
        end
private
        def to_hash array
            Hash[array.collect { |i| [i["key"].to_sym, i["value"]] }]
        end
        def load_credentials
            credentials = read_credentials
            return credentials if credentials.size >= 2
            update_configuration credentials
            read_credentials
        end
        def initialize
            @conf = ENV['awssecret'] || "#{ENV['HOME']}/.awssecret"
            credentials = load_credentials
            ENV['EC2_URL'] = credentials[2] if credentials.size >= 3
            require 'AWS' # *must* load AWS after setting EC2_URL
            @ec2 = AWS::EC2::Base.new access_key_id: credentials[0],
                secret_access_key: credentials[1]
        end
        def method_missing method, *args, &block
            described = "describe_#{method.to_s}".to_sym
            if @ec2.public_methods.include? method
                @ec2.send method, *args, &block
            elsif @ec2.public_methods.include? described
                @ec2.send described, *args, &block
            else
                puts "Usage: action parameters...", "available actions:"
                awesome_print (public_methods - "".public_methods)
                nil
            end
        end
    end
end
