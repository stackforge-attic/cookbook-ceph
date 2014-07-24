# encoding: UTF-8
#
# Cookbook Name:: ceph
# Attributes:: radosgw
#
# Copyright 2011, DreamHost Web Hosting
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

default['ceph']['radosgw']['api_fqdn'] = 'localhost'
default['ceph']['radosgw']['admin_email'] = 'admin@example.com'
default['ceph']['radosgw']['rgw_addr'] = '*:80'
default['ceph']['radosgw']['rgw_port'] = false
default['ceph']['radosgw']['webserver_companion'] = 'apache2' # can be false
default['ceph']['radosgw']['use_apache_fork'] = true
case node['platform']
when 'ubuntu'
  default['ceph']['radosgw']['init_style'] = 'upstart'
else
  default['ceph']['radosgw']['init_style'] = 'sysvinit'
end
