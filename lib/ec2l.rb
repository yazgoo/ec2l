require "ec2l/version"
require 'base64'
require 'awesome_print'
require 'pry'
# Public: Utilities to facilitate amazon EC2 administration
#
# Examples
#
#   Ec2l::Client.new.i
#       => {:instanceId=>"i-deadbeef", :instanceState=>
#                       {"code"=>"16", "name"=>"running"},
#            :ipAddress=>"10.1.1.2", :tagSet=>{:k=>"v"}
#           ...
module Ec2l
    # Public: Client to use amazon EC2 apis
    #
    # Examples
    #
    #   Client.new.instances(["ipAddress"])[0..1]
    #       => [{:ipAddress=>"10.1.1.2"}, {:ipAddress=>"10.1.1.1"}]
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
                rearrange_fields item, keep
                item = item.instancesSet.item[0].reject{|k, v| not keep.include? k}
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
        #   ins[0]
        #       => {:instanceId=>"i-deadbeef", :instanceState=>
        #                       {"code"=>"16", "name"=>"running"},
        #            :ipAddress=>"10.1.1.2", :tagSet=>{:k=>"v"}}
        #
        # Returns an array with instanceId, ipAddress, tagSet, instanceState in a hash
        def ins() instances ["instanceId", "ipAddress", "tagSet", "instanceState"] end
        # Public: get system log
        #
        # id - VM instance id
        #
        # Examples
        #
        #   log("i-deadbeef")[0..1]
        #       => ["Initializing cgroup subsys cpuset", "Initializing cgroup subsys cpu"]
        #
        # Returns an array containing the lines of the system log
        def log id
            Base64.decode64(@ec2.get_console_output(instance_id: id)["output"]).split("\r\n")
        end
        # Public: terminates a VM instance
        #
        # id - the VM instance id
        #
        # Examples
        #
        #   terminate "i-deadbeef"
        #
        # Returns information about the termination status
        def terminate(id) @ec2.terminate_instances(instance_id: id) end
        # Public: opens up a pry shell
        def shell() binding.pry end
        # Public: update the credentials configuration
        #
        # creds - current credentials
        #
        # Examples
        #   update_configuration
        #   Will try and update configuration in /home/yazgoo/.awssecret
        #   access key (foo): 
        #   secret access key (bar): 
        #   entry point (default being https://aws.amazon.com if blank)
        #        (http://ec2.aws.com): 
        #       => ["access key", "secret access key", 
        #           "entry point ..."]
        #
        # Returns the description of the updated fields
        def update_configuration creds = nil
            puts "Will try and update configuration in #{@conf}"
            creds = read_credentials if creds.nil?
            File.open(@conf, "w") do |f|
                ["access key", "secret access key",
                 "entry point (default being https://aws.amazon.com if blank)"
                ].each_with_index do |prompt, i|
                    line = prompt_line prompt, creds[i]
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
        def prompt_line prompt, cred
            printf "#{prompt} (#{creds? creds:""}): "
            line = $stdin.gets.chomp
            if line.empty? and creds.size > i then creds else line end
        end
        def to_hash array
            Hash[array.collect { |i| [i["key"].to_sym, i["value"]] }]
        end
        def load_credentials
            credentials = read_credentials
            return credentials if credentials.size >= 2
            update_configuration credentials
            read_credentials
        end
        def build_underlying_client credentials
            ENV['EC2_URL'] = credentials[2] if credentials.size >= 3
            require 'AWS' # *must* load AWS after setting EC2_URL
            AWS::EC2::Base.new access_key_id: credentials[0],
                secret_access_key: credentials[1]
        end
        # Internal: load underlying client based on configuration into @ec2,
        #   which is usefull if you've updated credentials
        #   note that EC2_URL won't be updated this way
        #
        # Examples
        #
        #  load
        #       =>#<AWS::EC2::Base:0x00000002eca868    
        #
        # Return the underlying client loaded
        def load
            @ec2 = build_underlying_client load_credentials
        end
        def initialize
            @conf = ENV['awssecret'] || "#{ENV['HOME']}/.awssecret"
            load
        end
        # Internal: try and find/launch the method on the 
        #   underlying client called by the method name
        #   or by describe_#{name}
        #
        # Examples
        #
        #  method_missing_ec2 :addresses
        #    => {"xmlns"=>"http://ec2.amazonaws.com/doc/2010-08-31/",
        #           ...
        #
        # Return the result of the underlying method call
        def method_missing_ec2 method, *args, &block
            [method, "describe_#{method.to_s}".to_sym].each do |meth|
                if @ec2.public_methods.include? meth
                    return @ec2.send meth, *args, &block
                end
            end
            nil
        end
        # Internal: try and call method_missing_ec2
        #   if its result is nil, display a list of the class
        #   public methods
        #
        # Examples
        #
        #  h
        #  =>Usage: action parameters...
        #    available actions:
        #    [
        #        [0]            associate(address, id) Ec2l::Client
        #        [1]                    i()            Ec2l::Client
        #    
        # Return the result of method_missing_ec2 or nil
        def method_missing method, *args, &block
            result = method_missing_ec2(method, *args, &block)
            return result if not result.nil?
            puts "Usage: action parameters...", "available actions:"
            awesome_print (public_methods - "".public_methods)
            nil
        end
        def rearrange_fields item, keep
            it = item.instancesSet.item[0]
            if keep.include? "groups" and item.groupSet
                it["groups"] = item.groupSet.item.map{|x| x.groupId }
            end
            if keep.include? "tagSet" and it.tagSet
                it["tagSet"] = to_hash(it.tagSet.item)
            end
        end
    end
end
