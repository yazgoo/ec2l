require "ec2l/version"
require 'base64'
module Ec2l
    class Client
        def to_hash array
            result = {}
            array.each { |i| result[i["key"].to_sym] = i["value"] }
            result
        end
        def instances keep = ["instanceId", "ipAddress", "groups",
                              "launchType", "instanceType", "tagSet"]
            r = []
            @ec2.describe_instances.reservationSet.item.each do |item|
                group = item.groupSet if keep.include? "groups"
                item = item.instancesSet.item[0].reject{|k, v| not keep.include? k}
                item["groups"] = group.item.map{|x| x.groupId } if not group.nil?
                item["tagSet"] = to_hash(item["tagSet"].item) if item["tagSet"]
                r << Hash[item.map { |k, v| [k.to_sym, v] }]
            end
            r
        end
        def instance(id) @ec2.describe_instances(instance_id: id) end
        def sgs
            r = []
            @ec2.describe_security_groups.securityGroupInfo.item.each do |item|
                r << item.reject { |k, v| not ["groupName", "ownerId"].include? k }
            end
            r
        end
        def i() instances ["instanceId", "ipAddress", "tagSet", "instanceState"] end
        def log id
            puts Base64.decode64 @ec2.get_console_output(instance_id: id)["output"]
        end
        def terminate(id) @ec2.terminate_instances(instance_id: id) end
        def shell
            require 'pry'
            Pry.config.pager = false
            binding.pry
        end
        def update_configuration
            puts "Will try and update configuration in #{@conf}"
            creds = read_credentials
            File.open(@conf, "w") do |f|
                ["access key", "secret access key",
                 "entry point (default being https://aws.amazon.com if left blank)"
                ].each_with_index do |prompt, i|
                    printf "#{prompt} (#{creds.size > i ? creds[i]:""}): "
                    line = gets.chomp
                    line = creds[i] if line.empty? and creds.size > i
                    f.puts line if not line.empty?
                end
            end
        end
        def read_credentials
            credentials = []
            return credentials if not File.exists? @conf
            File.open(@conf) { |f| f.each { |line| credentials << line.chomp } }
            credentials
        end
        def load_credentials
            update_configuration if not File.exists? @conf
            read_credentials
        end
        def initialize
            @conf = ENV['awssecret']
            @conf ||= "#{ENV['HOME']}/.awssecret"
            credentials = load_credentials
            ENV['EC2_URL'] = credentials[2] if credentials.size >= 3
            require 'AWS' # *must* load AWS after setting EC2_URL
            @ec2 = AWS::EC2::Base.new access_key_id: credentials[0],
                secret_access_key: credentials[1]
        end
    end
end
