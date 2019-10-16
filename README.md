# pginstaller
PostgreSQL 11 HA Cluster Installer For CentOS 7.x
These program installs PostgreSQL HA Cluster with Patroni in 10 minutes for new servers.


**IMPORTANT**

_**Do not use these program for your existing setup or upgrade your servers. You can lost your data be careful. pgInstaller well tested on just new servers.**_

# Requirements
* New installed CentOS 7.x servers (min 3 servers suggested) and root user enabled.
* Check all candidate servers has same root password. 
* Check default yum repos (sudo yum update) is reachable.
* Check https://yum.postgresql.org/        is reachable.
* Optinal add sperate disks for WAL and DATA for production env.


# Usage
        -n required- root user password. Remember all machines have to have SAME root password. You can change passwords or disable root login recommended after installation finished.
        -p required- IP list of cluster. Comma seperated IP list e.g : 192.168.1.1,192.168.1.2,192.168.1.3
        -s required- Scope Name e.g : PROD_CLS max 10 Alphetic charecter[a-Z]
        -k optinal- PostgreSQL port default : 5432
        -d optinal- Data disk path e.g : /dev/sdb
        -w optinal- WAL  disk path e.g : /dev/sdc
        -e optinal- DCS root directory path. e.g. PG11_PROD_CLS.if you not provide default value is  "PG_+ Scope Name"
        -v optinal- More output default for open add : -v:ON 
        -g optinal- Etcd Password (If you not provide the program generate for you and save it in PgInstallerPass.txt file)
        -t optinal- Postgres Replication User Password (If you not provide the program generate for you and save it in PgInstallerPass.txt file)
        -y optinal- Postgres Super User(postgres) Password (If you not provide the program generate for you and save it in PgInstallerPass.txt file)
        -u optinal- pgBackRest User(pgbackrest) Password (If you not provide the program generate for you and save it in PgInstallerPass.txt file)

# Example Usage
        ./installPG11Cluster -n "1" -p 172.16.242.129,172.16.242.130,172.16.242.131 -s AKCA_CLS -e PG11_AKCA_CLS -k 5432 -d /dev/sdb -w /dev/sdc -g 1a23 -t 1a23 -y 1a23 -u 1a23
    
# Compile to Portable Binary
        shc -rf installPG11Cluster.sh -o installPG11Cluster
        
        
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
* /etc/fstab (Only If you provide additional disk for DATA or WAL disk)
* /etc/selinux/config

# After Installation 

* It is recomended disable all root user's from your servers.

* The default servers firewalls are open so you have to open PostgreSQL port for connect from your app server/s. For accessing to database run these commands on all servers which is you provide during to installation with -p command. ;

Example,
- firewall-cmd --permanent --zone=public --add-rich-rule="rule family=ipv4 source address=${YOUR APP SERVER IP}/32 port protocol=tcp port=5432 accept"
- systemctl restart firewalld

* Review your PostgreSQL HA Cluster configuration

**patronictl -c /etc/patroni_${SCOPE_NAME}.yml edit-config**


_For more about cluster configuration read Patroni github page._


# Example connection

● Using jdbc:

jdbc:postgresql://node1,node2,node3/postgres?targetServerType=master

● libpq starting from PostgreSQL 10:

postgresql://host1:port2,host2:port2/?target_session_attrs=read-write

● For more balancer vs ... read Patroni github page.
 
# Waiting Features 
 * Backup server installation option will be added with pg_BackRest. 
 * pg_watch2  installation will be added.
 
