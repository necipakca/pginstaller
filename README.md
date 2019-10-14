# pginstaller
PostgreSQL 11/12 HA Cluster Installer For CentOS 7.x
These program installs PostgreSQL HA Cluster with Patroni in 10 minutes.

# Usage
        -n required- root user password. Remember all machines have to have SAME root password. You can change passwords or disable root login recommended after installation finished.
        -p required- IP list of cluster. Comma seperated IP list e.g : 192.168.1.1,192.168.1.2,192.168.1.3
        -s required- Scope Name e.g : PROD_CLS max 10 Alphetic charecter[a-Z]
        -k optinal- PostgreSQL port default : 5432
        -d optinal- Data disk path e.g : /dev/sdb
        -w optinal- WAL  disk path e.g : /dev/sdc
        -e optinal- DCS root directory path. e.g. PG11_PROD_CLS.if you not provide default value is  PG_+ Scope Name
        -v optinal- More output default for open add : -v:ON 
        -g optinal- Etcd Password
        -t optinal- Postgres Replication User Password
        -y optinal- Postgres Super User(postgres) Password
        -u optinal- pgBackRest User(pgbackrest) Password

# Example Usage
        ./installPG12Cluster -n "rootPassword" -p 172.16.242.129,172.16.242.130,172.16.242.131 -s MY_PROD_CLS -e PG11_MY_PROD_CLS -k 5432 -d /dev/sdb -w /dev/sdc
    
    
    
    
# Compile to Portable Binary
        shc -rf installPG12Cluster.sh -o installPG12Cluster
        
        
# Tuned Kernel & Conf Files

These files will be tuned or added to your server.
After succesfully install your PostgreSQL HA cluster we strongly recommend review these files.


* /etc/tuned/postgresql-tuned/tuned.conf
* /etc/systemd/system/postgresql-thp-disabler.service
* /etc/systemd/system/watchdog.service
* /etc/systemd/system/patroni_${SCOPE_NAME}.service

* /etc/sysctl.conf
* /etc/security/limits.conf

* /etc/etcd/etcd.conf
* /etc/patroni_${SCOPE_NAME}.yml
* /etc/fstab (Only If you provide additional disk for DATA or WAL)
* /etc/selinux/config

# After Installation 

The default servers firewalls are open.You have to open PostgreSQL port for connect from your app server/s. For accessing to database run these commands on all servers which is you provide during to installation with -p command. ;

Example,
- firewall-cmd --permanent --zone=public --add-rich-rule="rule family=ipv4 source address=${YOUR APP SERVER IP}/32 port protocol=tcp port=5432 accept"
- systemctl restart firewalld

# Example connection

● Using jdbc:
jdbc:postgresql://node1,node2,node3/postgres?targetServerType=master

● libpq starting from PostgreSQL 10:
postgresql://host1:port2,host2:port2/?target_session_attrs=read-write

For more read Patroni github page.
 
