# -*- mode: ruby -*-
# vi: set ft=ruby :

# base of ips that will be user
base_ip="192.168.35."

# first ip to be user, this will be assigned to the proxy and the nodes will receive and increment number from this one
first_ip=90

# number of proxies
number_of_proxies=1

# the number of pxc nodes
number_of_nodes=2

# create an array to store the list of proxy ips
proxy_ips = []
(1..number_of_proxies).each do |a|
  proxy_ips.push("#{base_ip}#{first_ip}")
  first_ip += 1
end

# variable to store gcomm address, this will be passed to provision_node.sh
gcomm_address=""

# create an array to store the list of ips
# build the list of ips for each node and gcomm address
node_ips = []
(1..number_of_nodes).each do |a|
  node_ips.push("#{base_ip}#{first_ip}")
  if a != 1
    gcomm_address="#{gcomm_address},"
  end
  gcomm_address="#{gcomm_address}#{base_ip}#{first_ip}"
  first_ip += 1
end

Vagrant.configure(2) do |config|

  if Vagrant.has_plugin?("vagrant-vbguest")
    config.vbguest.auto_update = false
  end

  (1..number_of_nodes).each do |i|
    config.vm.define "node#{i}" do |node|
      node.vm.box = "centos/7"
#      node.vbguest.auto_update = false
      node.vm.host_name = "node#{i}"
      node.vm.network "private_network", ip:node_ips[i-1]
      node.vm.provider :virtualbox do |vb|
        vb.customize ["modifyvm", :id, "--memory", "512"]
        vb.customize ["modifyvm", :id, "--cpus", "1"]
#        if i == 3
#	  vb.customize ["modifyvm", :id, "--cpuexecutioncap", "75"]
#        end
      end
      node.vm.provision :shell do |s|
        s.path = "provision_node.sh"
        s.args = [i, node_ips[i-1], gcomm_address, node_ips[0]]
      end
    end
  end
  (1..number_of_proxies).each do |i|
    config.vm.define "proxysql#{i}" do |proxy|
      proxy.vm.box = "centos/7"
#      proxy.vbguest.auto_update = false
      proxy.vm.host_name = "proxysql#{i}"
      proxy.vm.network "private_network", ip:proxy_ips[i-1]
      proxy.vm.provider :virtualbox do |vb|
          vb.customize ["modifyvm", :id, "--memory", "512"]
          vb.customize ["modifyvm", :id, "--cpus", "1"]
      end

      # remove the first ip from ips (proxy ip)
      proxy.vm.provision :shell do |s|
        s.path = "provision_proxy.sh"
        s.args = [number_of_nodes]
	(1..number_of_nodes).each do |i|
          s.args += [node_ips[i-1]]
	end
        s.args += [number_of_proxies]
	(1..number_of_proxies).each do |i|
	  s.args += [proxy_ips[i-1]]
	end
      end
    end
  end
end
