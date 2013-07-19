#
# Author:: Kyle Bader <kyle.bader@dreamhost.com>
# Cookbook Name:: ceph
# Recipe:: osd
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

# this recipe allows bootstrapping new osds, with help from mon

include_recipe "ceph::default"
include_recipe "ceph::conf"

package 'gdisk' do
  action :upgrade
end

mons = get_mon_nodes(node['ceph']['config']['environment'])
have_mons = !mons.empty?
mons = get_mon_nodes(node['ceph']['config']['environment'], "ceph_bootstrap_osd_key:*")

if not have_mons then
  Chef::Log.info("No ceph-mon found.")
else

  while mons.empty?
    if not have_quorum? then
      Chef::Log.info("Waiting for monitors to go into quorum.")
      sleep(1)
      mons = get_mon_nodes(node['ceph']['config']['environment'], "ceph_bootstrap_osd_key:*")
      if mons[0]["ceph_bootstrap_osd_key"] then
        ceph_bootstrap_osd_key = mons[0]["ceph_bootstrap_osd_key"]
      end
    else
      Chef::Log.info("We are in quorum, getting ceph_bootstrap_osd_key from ceph.")
      ceph_bootstrap_osd_key = %x[ceph auth get-or-create-key client.bootstrap-osd mon "allow command osd create ...; allow command osd crush set ...; allow command auth add * osd allow\\ * mon allow\\ rwx; allow command mon getmap"]
      raise 'adding or getting bootstrap-osd key failed' unless $?.exitstatus == 0
      mons = Hash["bypass" => 1]
    end
  end # while mons.empty?

  directory "/var/lib/ceph/bootstrap-osd" do
    owner "root"
    group "root"
    mode "0755"
  end

  # TODO cluster name
  cluster = 'ceph'

  execute "format as keyring" do
    command <<-EOH
      set -e
      # TODO don't put the key in "ps" output, stdout
      ceph-authtool '/var/lib/ceph/bootstrap-osd/#{cluster}.keyring' --create-keyring --name=client.bootstrap-osd --add-key='#{ceph_bootstrap_osd_key}'
      rm -f '/var/lib/ceph/bootstrap-osd/#{cluster}.keyring.raw'
    EOH
    creates "/var/lib/ceph/bootstrap-osd/#{cluster}.keyring"
  end

  if is_crowbar?
    ruby_block "select new disks for ceph osd" do
      block do
        do_trigger = false
        BarclampLibrary::Barclamp::Inventory::Disk.unclaimed(node).each do |disk|
          if disk.claim("Ceph")
            Chef::Log.info("Claiming #{disk.name} for Ceph")
          else
            Chef::Log.info("Failed to claim #{disk.name} for Ceph")
          end
        end

        disks = BarclampLibrary::Barclamp::Inventory::Disk.claimed(node,"Ceph").map do |d|
          d.device
        end.sort

        disks.sort.each { |disk|
          unless ::Kernel.system("grep -q \'#{disk}1$\' /proc/partitions")
            Chef::Log.info("Using unclaimed disk: #{disk}")
            #Make sure the disk is clean and using a GUID partition table
            ::Kernel.system("sgdisk -Z /dev/#{disk}")
            #TODO: allow for separate journal
            system 'ceph-disk-prepare', \
              "/dev/#{disk}"
            raise 'ceph-disk-prepare failed' unless $?.exitstatus == 0
          else
            Chef::Log.info("This disk may already be in use by Ceph. Remove the partitions if you wish to re-import it into your cluster.")
          end
        }
        if do_trigger
          system 'udevadm', \
            "trigger", \
            "--subsystem-match=block", \
            "--action=add"
          raise 'udevadm trigger failed' unless $?.exitstatus == 0
        end
      end
    end
  end
end