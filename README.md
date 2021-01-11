# ProxySQL with PXC

This vagrant provision a proxysql instace with 3 pxc nodes and 2 ProxySQL instances in cluster mode.

You can adjust the number of PXC nodes you want for your pxc by editing `number_of_nodes` on  `Vagrantfile`. Same goes for number of ProxySQL instances, adjust `number_of_proxies`.

IP's are created based on `base_ip` + `first_ip` from `Vagrantfile`. For example, if you want your ups to start at 192.168.10.10 adjust the variables as follow:

```
base_ip="192.168.10."
first_ip=10
```

MySQL `root` password is `sekret`
