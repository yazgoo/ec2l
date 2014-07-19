require "codeclimate-test-reporter"
CodeClimate::TestReporter.start
require 'test/unit'
require 'tempfile'
require 'base64'
require 'ec2l'
class MockEc2
    def method_missing method, *args, &block
        nil
    end
    def get_console_output stuff
        {"output" => Base64.encode64("hello")}
    end
end
class Ec2l::Client
    def build_underlying_client credentials
        MockEc2.new
    end
end
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
class EC2lTest < Test::Unit::TestCase
    def setup
        if @conf.nil?
            @conf = Tempfile.new "a"
            @conf.write "a\nb\n"
            @conf.close
        end
        ENV['awssecret'] = @conf.path
        @cli = Ec2l::Client.new
    end
    def test_configuration
        def $stdin.gets() 'same_old' end
        @cli.update_configuration
        creds = @cli.read_credentials
        assert creds.size == 3, creds.to_s
        creds.each { |cred| assert cred == 'same_old' }
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
        assert @cli.instance(nil).nil?
        assert @cli.log(nil) == ["hello"]
        assert @cli.terminate(nil).nil?
    end
    def test_rearrange_fields
        item = {}
        item.instancesSet = {}
        item.instancesSet.item = ["blah"]
        @cli.rearrange_fields nil, nil
    end
end
