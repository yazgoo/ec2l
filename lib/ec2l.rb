require "ec2l/version"
require 'base64'
require 'awesome_print'
require 'pry'
module Ec2l
    class Client
        # Public: return virtual machines instances
        #
        # keep  -   what field you want to extract.
        #           valid fields names are documented in ec2 apis
        #           groups is an arranged shortcut for groupSet
        #           tagSet is also rearranged
        #
        # Examples
        #
        #   instances(["ipAddress"])[0..1]
        #       => [{:ipAddress=>"10.1.1.2"}, {:ipAddress=>"10.1.1.1"}]
        #
        # Returns an array with all fields requested for each VM in a hash
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
        # Public: displays inforation about a VM instance
        #
        # id  -   the VM instance id
        #
        # Examples
        #
        #   instance "i-deadbeef"
        #       => {"xmlns"=>"http://ec2.amazonaws.com/doc/2010-08-31/",
        #        "requestId"=>"89375055-16de-4ab7-84b5-5651670e7e3b",
        #        "reservationSet"=>
        #         {"item"=>
        #          ...
        #
        # Returns a hash with description of the instance
        def instance(id) @ec2.describe_instances(instance_id: id) end
        # Public: associate an elastic address with a VM instance
        #
        # address   -   the elastic IP address
        # id        -   the VM instance id
        #
        # Examples
        #
        #   associate '10.1.1.2', 'i-deadbeef'
        #
        # Returns info about the association
        def associate address, id
            @ec2.associate_address public_ip: address, instance_id: id
        end
        # Public: return a list of inforation about declared security groups
        #
        # Examples
        #
        #   sgs[0..1]
        #       => [{"ownerId"=>"424242", "groupName"=>"sg1"},
        #            {"ownerId"=>"424242", "groupName"=>"sg2"}]
        #
        # Returns an array with for each SG, the ownerID and the groupName
        def sgs
            @ec2.describe_security_groups.securityGroupInfo.item.collect do |item|
                item.reject { |k, v| not ["groupName", "ownerId"].include? k }
            end
        end
        # Public: return virtual machines instances with few details
        #
        # Examples
        #
        #   i[0]
        #       => {:instanceId=>"i-deadbeef", :instanceState=>
        #                       {"code"=>"16", "name"=>"running"},
        #            :ipAddress=>"10.1.1.2", :tagSet=>{:k=>"v"}}
        #
        # Returns an array with instanceId, ipAddress, tagSet, instanceState in a hash
        def i() instances ["instanceId", "ipAddress", "tagSet", "instanceState"] end
        # Public: get system log
        #
        # id  -   the VM instance id
        #
        # Examples
        #
        #   log("i-deadbeef")[0..1]
        #       => ["Initializing cgroup subsys cpuset", "Initializing cgroup subsys cpu"]
        #
        # Return an array containing the lines of the system log
        def log id
            Base64.decode64(@ec2.get_console_output(instance_id: id)["output"]).split("\r\n")
        end
        # Public: terminates a VM instance
        #
        # id  -   the VM instance id
        #
        # Examples
        #
        #   terminate "i-deadbeef"
        #
        # Return information about the termination status
        def terminate(id) @ec2.terminate_instances(instance_id: id) end
        # Public: opens up a pry shell
        def shell() binding.pry end
        # Public: update the credentials configuration
        #
        # creds  -   current credentials
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
        # Public: reads credentials from configuration file
        #
        # Examples
        #
        #   read_credentials
        #       => ["accesskey", "scretkey", "https://entry.com"]
        #
        # Return a list with the credentials and entrypoint if defined
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
        def method_missing_ec2 method, *args, &block
            [method, "describe_#{method.to_s}".to_sym].each do |meth|
                if @ec2.public_methods.include? meth
                    return @ec2.send meth, *args, &block
                end
            end
            yield
        end
        def method_missing method, *args, &block
            method_missing_ec2 method, *args, &block do
                puts "Usage: action parameters...", "available actions:"
                awesome_print (public_methods - "".public_methods)
                nil
            end
        end
    end
end
