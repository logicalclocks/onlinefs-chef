include_attribute "kkafka"
include_attribute "ndb"
include_attribute "hops"

default['onlinefs']['version']                = "1.8-SNAPSHOT"
default['onlinefs']['download_url']           = "#{node['download_url']}/onlinefs/#{node['onlinefs']['version']}/onlinefs.tgz"

default['onlinefs']['user']                   = "onlinefs"
default['onlinefs']['user_id']                = '1521'
default['onlinefs']['group']                  = "onlinefs"
default['onlinefs']['group_id']               = '1516'

default['onlinefs']['home']                   = "#{node['install']['dir']}/onlinefs"
default['onlinefs']['etc']                    = "#{node['onlinefs']['home']}/etc"
default['onlinefs']['logs']                   = "#{node['onlinefs']['home']}/logs"
default['onlinefs']['bin']                    = "#{node['onlinefs']['home']}/bin"
default['onlinefs']['token']                  = "#{node['onlinefs']['etc']}/token"
default['onlinefs']['instance_id']            = ""

default['onlinefs']['java_start_heap_size']   = '1024M'
default['onlinefs']['java_max_heap_size']     = '4096M'

default['onlinefs']['config_dir']             = nil

# Data volume directories
default['onlinefs']['data_volume']['root_dir']  = "#{node['data']['dir']}/onlinefs"
default['onlinefs']['data_volume']['etc_dir']   = "#{node['onlinefs']['data_volume']['root_dir']}/etc"
default['onlinefs']['data_volume']['logs_dir']  = "#{node['onlinefs']['data_volume']['root_dir']}/logs"

default['onlinefs']['hopsworks']['email']     = "onlinefs@hopsworks.ai"
default['onlinefs']['hopsworks']['password']  = "onlinefspw"

default['onlinefs']['monitoring']             = 12800

default['onlinefs']['service']['thread_number'] = 10
default['onlinefs']['service']['ron_db_thread_number'] = 10
default['onlinefs']['service']['vector_db_thread_number'] = 5
default['onlinefs']['service']['get_session_retry_sleep_ms'] = 100
default['onlinefs']['service']['max_blacklist_size'] = 100

default['onlinefs']['rondb']['batch_size']           = 300
default['onlinefs']['rondb']['max_transactions']     = 1024
default['onlinefs']['rondb']['max_cached_sessions']  = 20
default['onlinefs']['rondb']['max_cached_instances'] = 1024
default['onlinefs']['rondb']['reconnect_timeout']    = 5
default['onlinefs']['rondb']['pool_size']            = 1
default['onlinefs']['rondb']['use_session_cache']    = "false"
default['onlinefs']['rondb']['use_dynamic_object_cache'] = "false"

# kafka
default['onlinefs']['kafka']['properties_file']   = "onlinefs-kafka.properties"
default['onlinefs']['kafka']['properties_file_vector_db']   = "onlinefs-kafka-vector-db.properties"

# kafka_consumer
default['onlinefs']['kafka_consumer']['topic_pattern']    = ".*_onlinefs"
default['onlinefs']['kafka_consumer']['topic_list']       = ""
default['onlinefs']['kafka_consumer']['poll_timeout_ms']  = 1000
default['onlinefs']['kafka_consumer']['ron_db_group_id']     = "onlinefs_rondb"
default['onlinefs']['kafka_consumer']['vector_db_group_id']  = "onlinefs_vectordb"

# Opensearch
default['onlinefs']['opensearch']['port']       = node['elastic']['port']
default['onlinefs']['opensearch']['user_name']  = node['elastic']['opensearch_security']['onlinefs']['username']
default['onlinefs']['opensearch']['password']   = node['elastic']['opensearch_security']['onlinefs']['password']
