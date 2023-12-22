### start of migration ###
# all available migration version in ascending order, the versions need to match the version of files in files/default/sql
migrate_versions = ["3.7.0"]
current_version = node['install']['current_version']
target_version = node['install']['version'].sub("-SNAPSHOT", "")
# Ignore patch versions starting from version 3.0.0
if Gem::Version.new(target_version) >= Gem::Version.new('3.0.0')
  target_version_ignore_patch_arr = target_version.split(".")
  target_version_ignore_patch_arr[2] = "0"
  target_version = target_version_ignore_patch_arr.join(".")
end

private_ip = my_private_ip()
is_first_node_to_run = private_ip.eql?(node['onlinefs']['default']['private_ips'].sort[0])

if !current_version.empty? && is_first_node_to_run
  target_gem_version = Gem::Version.new(target_version)
  current_gem_version = Gem::Version.new(current_version)

  migrate_versions.each do |migrate_version|
    migrate_gem_version = Gem::Version.new(migrate_version)

    if target_gem_version >= migrate_gem_version && migrate_gem_version > current_gem_version
      migrate_directory = "#{node['onlinefs']['data_volume']['etc_dir']}/migrate"
      directory migrate_directory do
        owner node['onlinefs']['user']
        group node['onlinefs']['group']
        mode "0750"
        action :create
      end
      sql_file_path = "#{migrate_directory}/#{migrate_gem_version}__update.sql"

      cookbook_file sql_file_path do
        source "sql/#{migrate_gem_version}__update.sql"
        owner node['onlinefs']['user']
        group node['onlinefs']['group']
        mode 0750
        action :create
      end

      bash "run_migrate_#{migrate_gem_version}" do
        user "root"
        code <<-EOH
          #{node['ndb']['scripts_dir']}/mysql-client.sh mysql < #{sql_file_path}
        EOH
      end
    end
  end
end

### end of migration ###

group node['onlinefs']['group'] do
  gid node['onlinefs']['group_id']
  action :create
  not_if "getent group #{node['onlinefs']['group']}"
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

user node['onlinefs']['user'] do
  home node['onlinefs']['user-home']
  uid node['onlinefs']['user_id']
  gid node['onlinefs']['group']
  action :create
  shell "/bin/nologin"
  manage_home true
  system true
  not_if "getent passwd #{node['onlinefs']['user']}"
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

group node['logger']['group'] do
  gid node['logger']['group_id']
  action :create
  not_if "getent group #{node['logger']['group']}"
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

user node['logger']['user'] do
  uid node['logger']['user_id']
  gid node['logger']['group_id']
  shell "/bin/nologin"
  action :create
  system true
  not_if "getent passwd #{node['logger']['user']}"
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

group node['onlinefs']['group'] do
  append true
  members [node['logger']['user']]
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

directory node['onlinefs']['data_volume']['root_dir'] do
  owner node['onlinefs']['user']
  group node['onlinefs']['group']
  mode "0750"
  action :create
end

directory node['onlinefs']['data_volume']['etc_dir'] do
  owner node['onlinefs']['user']
  group node['onlinefs']['group']
  mode "0750"
  action :create
end

directory node['onlinefs']['data_volume']['logs_dir'] do
  owner node['onlinefs']['user']
  group node['onlinefs']['group']
  mode "0750"
  action :create
end

['etc_dir', 'logs_dir'].each {|dir|
  directory node['onlinefs']['data_volume'][dir] do
    owner node['onlinefs']['user']
    group node['onlinefs']['group']
    mode "0750"
    action :create
  end
}

directory node['onlinefs']['home'] do
  owner node['onlinefs']['user']
  group node['onlinefs']['group']
  mode "0750"
  action :create
end

['etc', 'logs'].each {|dir|
  bash "Move onlinefs #{dir} to data volume" do
    user 'root'
    code <<-EOH
      set -e
      mv -f #{node['onlinefs'][dir]}/* #{node['onlinefs']['data_volume']["#{dir}_dir"]}
      rm -rf #{node['onlinefs'][dir]}
    EOH
    only_if { conda_helpers.is_upgrade }
    only_if { File.directory?(node['onlinefs'][dir])}
    not_if { File.symlink?(node['onlinefs'][dir])}
  end

  link node['onlinefs'][dir] do
    owner node['onlinefs']['user']
    group node['onlinefs']['group']
    mode "0750"
    to node['onlinefs']['data_volume']["#{dir}_dir"]
  end
}

directory node['onlinefs']['bin'] do
  owner node['onlinefs']['user']
  group node['onlinefs']['group']
  mode "0750"
  action :create
end

# Generate a certificate
instance_id = node['onlinefs']['instance_id']
if instance_id.casecmp?("")
  instance_id = private_recipe_ips("onlinefs", "default").sort.find_index(my_private_ip())
end

service_fqdn = consul_helper.get_service_fqdn("onlinefs")

crypto_dir = x509_helper.get_crypto_dir(node['onlinefs']['user'])
kagent_hopsify "Generate x.509" do
  user node['onlinefs']['user']
  crypto_directory crypto_dir
  common_name "#{instance_id}.#{service_fqdn}"
  action :generate_x509
  not_if { node["kagent"]["enabled"] == "false" }
end

# Generate an API key
api_key = nil
ruby_block 'generate-api-key' do
  block do
    require 'net/https'
    require 'http-cookie'
    require 'json'
    require 'securerandom'

    hopsworks_fqdn = consul_helper.get_service_fqdn("hopsworks.glassfish")
    _, hopsworks_port = consul_helper.get_service("glassfish", ["http", "hopsworks"])
    if hopsworks_port.nil? || hopsworks_fqdn.nil?
      raise "Could not get Hopsworks fqdn/port from local Consul agent. Verify Hopsworks is running with service name: glassfish and tags: [http, hopsworks]"
    end

    hopsworks_endpoint = "https://#{hopsworks_fqdn}:#{hopsworks_port}"
    url = URI.parse("#{hopsworks_endpoint}/hopsworks-api/api/auth/service")
    api_key_url = URI.parse("#{hopsworks_endpoint}/hopsworks-api/api/users/apiKey")

    params =  {
      :email => node['onlinefs']['hopsworks']['email'],
      :password => node['onlinefs']['hopsworks']["password"]
    }

    api_key_params = {
      :name => "onlinefs_" + SecureRandom.hex(12),
      :scope => "KAFKA"
    }

    response = http_request_follow_redirect(url, form_params: params)

    if( response.is_a?( Net::HTTPSuccess ) )
        # your request was successful
        puts "Onlinefs login successful: -> #{response.body}"

        api_key_url.query = URI.encode_www_form(api_key_params)
        response = http_request_follow_redirect(api_key_url,
                                                body: "",
                                                authorization: response['Authorization'])

        if ( response.is_a? (Net::HTTPSuccess))
          json_response = ::JSON.parse(response.body)
          api_key = json_response['key']
        else
          puts response.body
          raise "Error creating onlinefs api-key: #{response.uri}"
        end
      else
          puts response.body
          raise "Error onlinefs login"
      end
    end
end

# write api-key to token file
file node['onlinefs']['token'] do
  content lazy {api_key}
  mode 0750
  owner node['onlinefs']['user']
  group node['onlinefs']['group']
end

# Template the configuration file
hopsworks_internal_port = 8182
if node.attribute?('hopsworks')
  if node['hopsworks'].attribute?('internal') and node['hopsworks']['internal'].attribute?('port')
    hopsworks_internal_port = node['hopsworks']['internal']['port']
  end
end
hopsworks_url = "https://#{consul_helper.get_service_fqdn("hopsworks.glassfish")}:#{hopsworks_internal_port}"
opensearch_url = "https://#{consul_helper.get_service_fqdn("elastic")}:#{node['onlinefs']['opensearch']['port']}"

mgm_fqdn = consul_helper.get_service_fqdn("#{node['ndb']['mgmd']['consul_tag']}.rondb")
template "#{node['onlinefs']['etc']}/onlinefs-site.xml" do
  source "onlinefs-site.xml.erb"
  owner node['onlinefs']['user']
  group node['onlinefs']['group']
  mode 0750
  variables(
    {
      :mgm_fqdn => mgm_fqdn,
      :hopsworks_url => hopsworks_url,
      :opensearch_url => opensearch_url
    }
  )
end

ruby_block 'copy-config-dir' do
  block do
    require 'fileutils'

    # Copy everything from the provided config_dir to etc overwriting any duplicates
    FileUtils.cp_r(Dir["#{node['onlinefs']['config_dir']}/*"], node['onlinefs']['etc'])
  end
  not_if { node['onlinefs']['config_dir'].nil? }
end

kafka_fqdn = consul_helper.get_service_fqdn("broker.kafka")
template "#{node['onlinefs']['etc']}/#{node['onlinefs']['kafka']['properties_file']}" do
  source "onlinefs-kafka.properties.erb"
  owner node['onlinefs']['user']
  group node['onlinefs']['group']
  mode 0750
  variables(
    {
      :kafka_fqdn => kafka_fqdn,
      :group_id   => "#{node['onlinefs']['kafka_consumer']['ron_db_group_id']}"
    }
  )
  only_if { node['onlinefs']['config_dir'].nil? }
end

template "#{node['onlinefs']['etc']}/#{node['onlinefs']['kafka']['properties_file_vector_db']}" do
  source "onlinefs-kafka.properties.erb"
  owner node['onlinefs']['user']
  group node['onlinefs']['group']
  mode 0750
  variables(
    {
      :kafka_fqdn => kafka_fqdn,
      :group_id   => "#{node['onlinefs']['kafka_consumer']['vector_db_group_id']}"
    }
  )
  only_if { node['onlinefs']['config_dir'].nil? }
end

template "#{node['onlinefs']['etc']}/log4j.properties" do
  source "log4j.properties.erb"
  owner node['onlinefs']['user']
  group node['onlinefs']['group']
  mode 0750
end

template "#{node['onlinefs']['bin']}/waiter.sh" do
  source "waiter.sh.erb"
  owner node['onlinefs']['user']
  group node['onlinefs']['group']
  mode 0750
end

# Download and load the Docker image
image_url = node['onlinefs']['download_url']
base_filename = File.basename(image_url)
remote_file "#{Chef::Config['file_cache_path']}/#{base_filename}" do
  source image_url
  action :create
end

# Load the Docker image
registry_image = "#{consul_helper.get_service_fqdn("registry")}:#{node['hops']['docker']['registry']['port']}/onlinefs:#{node['onlinefs']['version']}"
image_name = "docker.hops.works/onlinefs:#{node['onlinefs']['version']}"
bash "import_image" do
  user "root"
  code <<-EOF
    set -e
    docker load -i #{Chef::Config['file_cache_path']}/#{base_filename}
    docker tag #{image_name} #{registry_image}
    docker push #{registry_image}
  EOF
  not_if "docker image inspect #{registry_image}"
end

# Add Systemd unit file
service_name="onlinefs"
case node['platform_family']
when "rhel"
  systemd_script = "/usr/lib/systemd/system/#{service_name}.service"
else
  systemd_script = "/lib/systemd/system/#{service_name}.service"
end

service service_name do
  provider Chef::Provider::Service::Systemd
  supports :restart => true, :stop => true, :start => true, :status => true
  action :nothing
end

local_systemd_dependencies = ""
if service_discovery_enabled()
  local_systemd_dependencies += "consul.service"
end
if exists_local("kkafka", "default")
  local_systemd_dependencies += " kafka.service"
end

template systemd_script do
  source "#{service_name}.service.erb"
  owner "root"
  group "root"
  mode 0664
  action :create
  if node['services']['enabled'] == "true"
    notifies :enable, "service[#{service_name}]"
  end
  variables({
    :crypto_dir => crypto_dir,
    :kafka_fqdn => kafka_fqdn,
    :image_name => registry_image,
    :local_dependencies => local_systemd_dependencies
  })
end

kagent_config "#{service_name}" do
  action :systemd_reload
end

# Register with kagent
if node['kagent']['enabled'] == "true"
  kagent_config service_name do
    service "feature store"
  end
end

# Register with consul
if service_discovery_enabled()
  # Register online fs with Consul
  consul_service "Registering OnlineFS with Consul" do
    service_definition "onlinefs.hcl.erb"
    action :register
  end
end

bash 'wait-for-onlinefs' do
  user node['onlinefs']['user']
  group node['onlinefs']['group']
  timeout 250
  code <<-EOH
      #{node['onlinefs']['bin']}/waiter.sh
  EOH
end
