name              "onlinefs"
maintainer        "Logical Clocks"
maintainer_email  'info@logicalclocks.com'
license           'GPLv3'
description       'Installs/Configures the Hopsworks online feature store service'
long_description  IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version           "3.1.0"

recipe "onlinefs::default", "Configures the Hopsworks online feature store service"

depends 'kkafka'
depends 'ndb'
depends 'hops'
depends 'kagent'
depends 'consul'

attribute "onlinefs/user",
          :description => "User to run the online feature store service",
          :type => "string"

attribute "onlinefs/user_id",
          :description => "onlinefs user id. Default: 1521",
          :type => "string"

attribute "onlinefs/group",
          :description => "Group of the user running the online feature store service",
          :type => "string"

attribute "onlinefs/group_id",
          :description => "onlinefs group id. Default: 1516",
          :type => "string"

attribute "onlinefs/service/thread_number",
          :description => "number of threads reading from kafka and writing to rondb",
          :type => "string"

attribute "onlinefs/service/get_session_retry_sleep_ms",
          :description => "time in ms for threads to sleep between the retries of getting session",
          :type => "string"

attribute "onlinefs/monitoring",
          :description => "Port on which the monitoring page is available",
          :type => "string"

attribute "onlinefs/rondb/batch_size",
          :description => "batch size to commit to rondb (Default: 300)",
          :type => "string"

attribute "onlinefs/rondb/max_cached_sessions",
          :description => "max number of cached clusterj sessions (Default: 20)",
          :type => "string"

attribute "onlinefs/rondb/max_cached_instances",
          :description => "max number of cached clusterj instances (Default: 1024)",
          :type => "string"

attribute "onlinefs/rondb/reconnect_timeout",
          :description => "reconnect timeout for clusterj session factory (Default: 5)",
          :type => "string"

attribute "onlinefs/rondb/max_transactions",
          :description => "max number of concurrent clusterj transactions (Default: 1024)",
          :type => "string"

attribute "onlinefs/rondb/pool_size",
          :description => "Size of the connection pool for each session factory (Default: 1)",
          :type => "string"

attribute "onlinefs/rondb/use_session_cache",
          :description => "Whether to use clusterj session cache functionality (Default: false)",
          :type => "string"

attribute "onlinefs/rondb/use_dynamic_object_cache",
          :description => "Whether to use clusterj dynamic object cache functionality (Default: false)",
          :type => "string"

attribute "onlinefs/download_url",
          :description => "Download url for the onlinefs.tgz binaries",
          :type => "string"
