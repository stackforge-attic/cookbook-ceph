# encoding: UTF-8
#
# Author:: Kyle Bader <kyle.bader@dreamhost.com>
# Cookbook Name:: ceph
# Recipe:: radosgw
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

node.default['ceph']['extras_repo'] = true

case node['platform_family']
when 'debian'
  packages = %w(
    tgt
  )
when 'rhel', 'fedora'
  packages = %w(
    scsi-target-utils
  )
end

packages.each do |pkg|
  package pkg do
    action :upgrade
  end
end

include_recipe 'ceph::conf'
# probably needs the key
service 'tgt' do
  if node['platform'] == 'ubuntu'
    # The ceph version of tgt does not provide an Upstart script
    provider Chef::Provider::Service::Init::Debian
    service_name 'tgt'
  else
    service_name 'tgt'
  end
  supports restart: true
  action [:enable, :start]
end
