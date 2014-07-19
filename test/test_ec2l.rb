require "codeclimate-test-reporter"
CodeClimate::TestReporter.start
require 'test/unit'
require 'tempfile'
require 'base64'
require 'ec2l'
class Hash
    def method_missing method, *args, &block
        method = method.to_s
        if method.end_with? "="
            self[method.to_s[0..-2]] = args[0]
        else
            self[method]
        end
    end
end
class Client < Ec2l::Client
    def build_underlying_client credentials
        if credentials.size == 3 and credentials[2] == 'through'
            super credentials
        else
            MockEc2.new
        end
    end
end
$instance_set = {"reservationSet" => {"item" => [{"instancesSet" => {
            "item" => [{"instanceId" => "lol"}]}}]}}
class MockEc2
    def method_missing method, *args, &block
        nil
    end
    def describe_instances stuff = nil
        $instance_set
    end
    def describe_security_groups
        {"securityGroupInfo" => {"item" => [] }}
    end
    def get_console_output stuff
        {"output" => Base64.encode64("hello")}
    end
end
class EC2lTest < Test::Unit::TestCase
    def create_conf creds
        conf = Tempfile.new "a"
        conf.write creds.join "\n"
        conf.close
        conf.path
    end
    def setup
        ENV['awssecret'] = create_conf ['a', 'b']
        @cli = Client.new
    end
    def test_configuration
        def $stdin.gets() 'same_old' end
        @cli.update_configuration
        creds = @cli.read_credentials
        assert creds.size == 3, creds.to_s
        creds.each { |cred| assert cred == 'same_old' }
        ENV['awssecret'] = create_conf([])
        Client.new.send :load_credentials
    end
    def test_method_missing
        assert @cli.h.nil?
        assert @cli.send(:method_missing_ec2, :h).nil?
    end
    def test_utilities
        result = @cli.send :to_hash, [{"key" => "hello", "value" => "world"}]
        assert result == {hello: "world"}
    end
    def test_basic_underlying_calls
        assert @cli.associate(nil, nil).nil?
        assert @cli.instance(nil) == $instance_set
        assert @cli.log(nil) == ["hello"]
        assert @cli.terminate(nil).nil?
    end
    def test_rearrange_fields
        item = {"instancesSet" => {"item" => [{"tagSet" => {"item" => []}}]},
                "groupSet" => {"item" => [{}] } }
        @cli.send :rearrange_fields, item, ["groups", "tagSet"]
    end
    def test_complex_calls
        assert @cli.describe_instances == $instance_set
        assert @cli.sgs == []
    end
    def test_underlying_client_initialization
        x = nil
        begin
            @cli.build_underlying_client ['a', 'b', 'through']
        rescue Exception => e
            x = e
        end
        assert not(x.nil?)
    end
end
