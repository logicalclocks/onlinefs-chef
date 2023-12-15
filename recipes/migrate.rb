versions = node['onlinefs']['migrate']['versions'].split(/\s*,\s*/)

database_names = []
ruby_block 'check_versions_and_run_recipe' do
  block do
    if versions.empty?
      Chef::Log.warn('Skipping recipe due to empty versions')
    else
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
      projects_url = URI.parse("#{hopsworks_endpoint}/hopsworks-api/api/project/getAll")

      params =  {
        :email => node['onlinefs']['hopsworks']['email'],
        :password => node['onlinefs']['hopsworks']["password"]
      }

      response = http_request_follow_redirect(url, form_params: params)

      if( response.is_a?( Net::HTTPSuccess ) )
        # your request was successful
        puts "Onlinefs login successful: -> #{response.body}"

        response = http_request_follow_redirect(projects_url,
                                                body: "",
                                                authorization: response['Authorization'])

        if ( response.is_a? (Net::HTTPSuccess))
          projects = ::JSON.parse(response.body)
          projects.each do |project|
            database_names << project['name'].downcase
          end
        else
          puts response.body
          raise "Error creating getting project names: #{response.uri}"
        end
      else
        puts response.body
        raise "Error onlinefs login"
      end

      for version in versions do
        for database in database_names do
          cookbook_file "#{default['onlinefs']['data_volume']['etc_dir']}/migrate/#{version}__update.sql" do
            source "sql/#{version}__update.sql"
            owner node['onlinefs']['user']
            mode 0750
            action :create
          end

          bash "run_migrate_#{version}" do
            user "root"
            code <<-EOH
              #{node['ndb']['scripts_dir']}/mysql-client.sh #{database} < #{default['onlinefs']['data_volume']['etc_dir']}/migrate/#{version}__update.sql
            EOH
          end
        end
      end
    end
  end
end

