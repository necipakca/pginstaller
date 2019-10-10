# pginstaller
PostgreSQL HA Cluster Installer For CentOS 7.x

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
        