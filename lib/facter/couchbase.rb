# Fact: couchbase_data_path
#
# Purpose: To determine the current data path value.
#
# Resolution: Returns the path.

require 'json'

class Couchbase
  
  COUCHBASE_CONFIG_DAT = '/opt/couchbase/var/lib/couchbase/config/config.dat' unless const_defined?(:COUCHBASE_CONFIG_DAT)
  COUCHBASE_CLI = '/opt/couchbase/bin/couchbase-cli' unless const_defined?(:COUCHBASE_CLI)
  COUCHBASE_HOST = 'localhost' unless const_defined?(:COUCHBASE_HOST)
  ERLANG = '/opt/couchbase/bin/erl' unless const_defined?(:ERLANG)
  
  def initialize(username = nil, password = nil)
    @username = username
    @password = password
  end
  
  def username 
    @username = retrieve_username unless @username
    @username
  end
  
  def password
    @password = retrieve_password(username) unless @password
    @password
  end
  
  def installed?
    File.exist?(COUCHBASE_CONFIG_DAT)
  end
  
  def retrieve_data_path
    server_info = retrieve_server_info
    server_info['storage']['hdd'][0]['path']
  end

  private

  # Get couchbase username from config.dat
  def retrieve_username
    erlang_output = `#{ERLANG} -noinput -eval 'case file:read_file(\"#{COUCHBASE_CONFIG_DAT}\") of  {ok, B} -> io:format(\"~p~n\", proplists:get_keys(proplists:get_value(creds, proplists:get_value(rest_creds, lists:last(binary_to_term(B)))))) end.' -run init stop`
    erlang_output.gsub('"', '').delete("\n")
  end

  # Get couchbase user password from config.dat
  def retrieve_password(username)
    erlang_output = `#{ERLANG} -noinput -eval 'case file:read_file(\"#{COUCHBASE_CONFIG_DAT}\") of {ok, B} -> io:format(\"~p~n\", [proplists:get_value(password, proplists:get_value(\"#{username}\", proplists:get_value(creds, proplists:get_value(rest_creds, lists:last(binary_to_term(B))))))]) end.' -run init stop`
    erlang_output.gsub('"', '').delete("\n")
  end

  def retrieve_server_info
    cli_output = `#{COUCHBASE_CLI} server-info -c #{COUCHBASE_HOST} -u '#{username}' -p '#{password}'`
    JSON.parse(cli_output)
  end

end

cb = Couchbase.new
if cb.installed?
  Facter.add(:couchbase_data_path) do
    setcode do
      cb.retrieve_data_path
    end
  end
end