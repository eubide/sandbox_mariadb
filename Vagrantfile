# -*- mode: ruby -*-
# vi: set ft=ruby :
base_ip = "192.168.35."

# number of proxies
number_of_proxies = 2
first_ip_proxies = 60

# number of nodes
number_of_nodes = 3
first_ip_nodes = 70

# create an array to store the list of proxy ips
proxy_ips = []

(1..number_of_proxies).each do |_a|
  proxy_ips.push("#{base_ip}#{first_ip_proxies}")
  first_ip_proxies += 1
end

puts("---")
puts("number of proxysql nodes: #{number_of_proxies}")
puts("ips: #{proxy_ips.join(", ")}")

# variable to store gcomm address, this will be passed to provision_node.sh
gcomm_address = ""

# create an array to store the list of ips
# build the list of ips for each node and gcomm address
node_ips = []

(1..number_of_nodes).each do |a|
  node_ips.push("#{base_ip}#{first_ip_nodes}")
  gcomm_address = "#{gcomm_address}," if a != 1
  gcomm_address = "#{gcomm_address}#{base_ip}#{first_ip_nodes}"
  first_ip_nodes += 1
end

puts("---")
puts("number of pxc nodes: #{number_of_nodes}")
puts("ips: #{node_ips.join(", ")}")
puts("---")

# LC_ALL
ENV["LC_ALL"] = "en_US.UTF-8"

Vagrant.configure(2) do |config|
  config.vbguest.auto_update = false if Vagrant.has_plugin?("vagrant-vbguest")

  (1..number_of_nodes).each do |i|
    config.vm.define("node#{i}") do |node|
      node.vm.box = "centos/7"
      node.vm.host_name = "node#{i}"
      node.vm.network("private_network",       ip: node_ips[i - 1])

      node.vm.provider(:virtualbox) do |vb|
        vb.customize(["modifyvm", :id, "--memory", "1024"])
        vb.customize(["modifyvm", :id, "--cpus", "1"])
      end

      # if i == 3
      #  vb.customize ["modifyvm", :id, "--cpuexecutioncap", "75"]
      # end
      node.vm.provision(:shell) do |s|
        s.path = "provision_node.sh"
        s.args = [i, node_ips[i - 1], gcomm_address, node_ips[0]]
      end
    end
  end

  (1..number_of_proxies).each do |i|
    config.vm.define("proxysql#{i}") do |proxy|
      proxy.vm.box = "centos/7"
      proxy.vm.host_name = "proxysql#{i}"
      proxy.vm.network("private_network",       ip: proxy_ips[i - 1])

      proxy.vm.provider(:virtualbox) do |vb|
        vb.customize(["modifyvm", :id, "--memory", "512"])
        vb.customize(["modifyvm", :id, "--cpus", "1"])
      end

      # remove the first ip from ips (proxy ip)
      proxy.vm.provision(:shell) do |s|
        s.path = "provision_proxy.sh"
        s.args = [number_of_nodes]

        (1..number_of_nodes).each do |i|
          s.args += [node_ips[i - 1]]
        end

        s.args += [number_of_proxies]

        (1..number_of_proxies).each do |i|
          s.args += [proxy_ips[i - 1]]
        end
      end
    end
  end
end
