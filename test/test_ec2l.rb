require "codeclimate-test-reporter"
CodeClimate::TestReporter.start
require 'test/unit'
require 'tempfile'
require 'ec2l'
class Ec2l::Client
    def build_underlying_client credentials
        nil
    end
end
class EC2lTest < Test::Unit::TestCase
    def test_initialize
        if @conf.nil?
            @conf = Tempfile.new "a"
            @conf.write "a\nb\n"
            @conf.close
        end
        ENV['awssecret'] = @conf.path
        client = Ec2l::Client.new
        client
    end
    def test_configuration
        client = test_initialize
        def $stdin.gets() 'same_old' end
        client.update_configuration
        creds = client.read_credentials
        assert creds.size == 3, creds.to_s
        creds.each { |cred| assert cred == 'same_old' }
    end
    def test_method_missing
        assert test_initialize.h.nil?
        assert test_initialize.send(:method_missing_ec2, :h).nil?
    end
    def test_utilities
        client = test_initialize
        result = client.send :to_hash, [{"key" => "hello", "value" => "world"}]
        assert result == {hello: "world"}
    end
end
