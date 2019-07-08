#!/bin/sh
[[ "$(whoami)" != "root" ]] && exec sudo -- "$0" "$@"

RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
NORMAL=$(tput sgr0)

ACCEPTABLE_DIFF_OF_DATA_DISK_AS_GB=10
ACCEPTABLE_DIFF_OF_WAL_DISK_AS_GB=10

OS_ROOT_PASSWORD=
IP_LIST_OF_CLUSTER=
DATA_PATH=
WAL_PATH=
LVM_ALIAS=
SCOPE_NAME=
DSC_ROOT_PATH=
VERBOSE=
PG_PORT=
RUN_LEVEL=
ETCD_PASSWORD=
REPLICATION_USER_PASSWORD=
PG_SUPER_USER_PASSWORD=


banner(){
  echo "+----------------------------------------------------+"
  printf "| %-50s |\n" "`date`"
  echo "|                                                    |"
  printf "|`tput bold` %-50s `tput sgr0`|\n" "$@"
  echo "+----------------------------------------------------+"
}
bannerWithoutTime(){
  echo "+----------------------------------------------------+"
  printf "|`tput bold` %-50s `tput sgr0`|\n" "$@"
  echo "+----------------------------------------------------+"
}

bannerWithoutTime "PosgreSQL  11  HA  Cluster  Installer"
bannerWithoutTime "© All Rights Reserved by TURKSAT A.S."


function checkCommandStatus(){
    if [[ $? -eq 0 ]]; then
        echo $1 "......"${GREEN}"OK${NORMAL}";
    else
        echo $1 "......"${RED}"FAILED${NORMAL}";
        exit -900
    fi
}

function helpFunction(){
   echo ""
   echo "Usage: $0 ${RED}-n${NORMAL} ROOT_USER_PASS ${RED}-p${NORMAL} IP_LIST_OF_CLUSTER ${RED}-s${NORMAL} SCOPE_NAME ${GREEN}-d${NORMAL} DATA_DISK_PATH ${GREEN}-w${NORMAL} WAL_DISK_PATH ${GREEN}-e${NORMAL} DCS_ROOT_PATH ${GREEN}-k${NORMAL}PG_PORT ${GREEN}-g${NORMAL}ETCD_PASS ${GREEN}-t${NORMAL}REPLICATIN_USER_PASS ${GREEN}-y${NORMAL}SUPER_USER_PASS ${GREEN}-v${NORMAL} ON"
   echo -e "\t-n required- root user password. Remember all machines have to have SAME root password. You can change passwords or disable root login recommended after installation finished."
   echo -e "\t-p required- IP list of cluster. Comma seperated IP list e.g : 192.168.1.1,192.168.1.2,192.168.1.3"
   echo -e "\t-s required- Scope Name e.g : PROD_CLS max 10 Alphetic charecter[a-Z]"


   echo -e "\t-k optinal- PostgreSQL port default : 5432"
   echo -e "\t-b optinal- HaProxy(Balancer) Ip info e.g : 192.168.1.1 default is first IP of IP_LIST_OF_CLUSTER"
   echo -e "\t-d optinal- Data disk path e.g : /dev/sdb"
   echo -e "\t-w optinal- WAL  disk path e.g : /dev/sdc"
   echo -e "\t-e optinal- DCS root directory path. e.g. PG11_PROD_CLS.if you not provide default value is  PG_+ Scope Name"
   echo -e "\t-v optinal- More output default for open add : -v:ON "
   echo -e "\t-g optinal- Etcd Password"
   echo -e "\t-t optinal- Postgres Replication User Password"
   echo -e "\t-y optinal- Postgres Super User(postgres) Password"

   exit -900 # Exit script after printing help
}

function check_program_exist(){
  command -v "$1" >/dev/null 2>&1
}

while getopts 'n:p:s:d:w:e:v:k:x:g:t:y:' OPTION; do
  case "$OPTION" in
    n)
      OS_ROOT_PASSWORD="$OPTARG"
      ;;
    p)
      IP_LIST_OF_CLUSTER="$OPTARG"
      ;;
    s)
      SCOPE_NAME="$OPTARG"
      ;;
    d)
      DATA_PATH="$OPTARG"
      ;;
    w)
      WAL_PATH="$OPTARG"
      ;;
    e)
      DSC_ROOT_PATH="$OPTARG"
      ;;
    v)
      VERBOSE="$OPTARG"
      ;;
    k)
      PG_PORT="$OPTARG"
      ;;
    x)
      RUN_LEVEL="$OPTARG"
      ;;
    g)
      ETCD_PASSWORD="$OPTARG"
      ;;
    t)
      REPLICATION_USER_PASSWORD="$OPTARG"
      ;;
    y)
      PG_SUPER_USER_PASSWORD="$OPTARG"
      ;;
    ?)
      helpFunction
      ;;
  esac
done
shift "$(($OPTIND -1))"


# Print helpFunction in case parameters are empty
if [[ -z ${OS_ROOT_PASSWORD} ]] || [[ -z ${IP_LIST_OF_CLUSTER} ]] || [[ -z ${SCOPE_NAME} ]];then
   echo "######### Invalid Usage #########";
   helpFunction
fi


# Initialize Default Required params if not supplied
if [[ -z ${PG_PORT} ]] ;then
   checkCommandStatus "PostgreSQL port : 5432"
   PG_PORT="5432"
fi

if [[ -z ${ETCD_PASSWORD} ]] ;then
   ETCD_PASSWORD=$(head /dev/urandom | tr -dc A-Z0-9 | head -c 8)
   echo
   checkCommandStatus "${RED}ETCD_PASSWORD password generated please note this:${NORMAL} ${ETCD_PASSWORD}"
fi

if [[ -z ${REPLICATION_USER_PASSWORD} ]] ;then
   REPLICATION_USER_PASSWORD=$(head /dev/urandom | tr -dc A-Z0-9 | head -c 8)
   echo
   checkCommandStatus "${RED}REPLICATION_USER_PASSWORD password generated please note this:${NORMAL} ${REPLICATION_USER_PASSWORD}"
fi

if [[ -z ${PG_SUPER_USER_PASSWORD} ]] ;then
   PG_SUPER_USER_PASSWORD=$(head /dev/urandom | tr -dc A-Z0-9 | head -c 8)
   echo
   checkCommandStatus "${RED}PG_SUPER_USER_PASSWORD password generated please note this:${NORMAL} ${PG_SUPER_USER_PASSWORD}"
   echo
fi


handle_eco(){
    if [[ "${VERBOSE}" == "ON" ]]
    then
        echo $1
    fi
}

install_ssh_id(){
    if check_program_exist ssh-keygen; then
        checkCommandStatus "ssh-keygen"
    else
        sudo yum install ssh-keygen -y  >&-
        checkCommandStatus "ssh-keygen"
    fi

    if check_program_exist sshpass; then
        checkCommandStatus "sshpass"
    else
        sudo yum install sshpass -y  >&-
        checkCommandStatus "sshpass"
    fi

    if [[ -f /root/.ssh/id_rsa ]]; then
        handle_eco "${GREEN}RSA exist.${NORMAL}"
    else
        ssh-keygen -t rsa -b 2048 -N "" -f ~/.ssh/id_rsa >&-
        checkCommandStatus "RSA generate"
    fi

    sshpass -p "$OS_ROOT_PASSWORD" ssh-copy-id -o StrictHostKeyChecking=no root@$1 2>> installPGCluster.log
    checkCommandStatus "ssh-copy-id"
}

get_disk_size(){
    echo $(ssh -q -oStrictHostKeyChecking=no root@$1  DISK_PATH=$2 2>> installPGCluster.log  'bash -s' <<-'ENDSSH'
        blockdev --getsize64 ${DISK_PATH}
ENDSSH
    )
}

checkInternetConnections(){
    checkCommandStatus $(ssh -q -oStrictHostKeyChecking=no root@$1 IP=${1}  2>> installPGCluster.log  'bash -s' <<-'ENDSSH'
        curl -s --head https://bootstrap.pypa.io/get-pip.py | head -n 1 | grep "HTTP/1.[01] [23].." > /dev/null
        echo "${IP}:    Checking server can access the url https://bootstrap.pypa.io/get-pip.py.c for pip install"
ENDSSH
    )

    checkCommandStatus $(ssh -q -oStrictHostKeyChecking=no root@$1 IP=${1}  2>> installPGCluster.log  'bash -s' <<-'ENDSSH'
        curl -s --head https://yum.postgresql.org/11/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm | head -n 1 | grep "HTTP/1.[01] [23].." > /dev/null
        echo "${IP}:    Checking server can access the url https://yum.postgresql.org/11/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm for PG11 repo install"
ENDSSH
    )
}

check_disk_mount_status(){
    local STATUS_DATA_MOUNT=$(ssh -q -oStrictHostKeyChecking=no root@$1  DISK_PATH=$2 2>> installPGCluster.log  'bash -s' <<-'ENDSSH'
        if [[ $(partprobe -d -s ${DISK_PATH} | grep 'partitions') = "" ]] ; then
            echo "NOT_MOUNTED"
        else
            echo "MOUNTED"
        fi
ENDSSH
    )

    if [[ "${STATUS_DATA_MOUNT}" == "MOUNTED" ]] ; then
        echo "${RED}IMPORTANT : If you are on PRODUCTION env just exit please. The disk ${DISK_PATH} has a partition but it should not have.";
        echo "$1:$2 has partition table please unmount disk and clean partition table e.g (wipefs -aqf $2)."
        echo "If you want to try this program on empty machine with no data it, You can continue. But be sure disk unmounted this program will not unmount for you";
        echo "Please read documentation on GITHUB and verify Disks chapter.";
        echo "Disk ${DISK_PATH} has already partition on it.";
        echo "Disk ${DISK_PATH} will be purge, You will lost all data on disk ${DISK_PATH}.${NORMAL}";
        while true
        do
            read -r -p "Are you sure? [Y/n] " input
            case $input in
                [yY][eE][sS]|[yY])
                    break;
                ;;
                [nN][oO]|[nN])
                     exit -900
                ;;
                *)
                echo "Invalid exiting input..."
                exit -900
            ;;
            esac
        done
    fi
}

validate_disks(){


    if [[ -z ${DATA_PATH} ]]; then
        echo ${IP} ":   ""${YELLOW}INFO:${NORMAL} DATA disk not not provided.It is recommended to seperate OS/DATA/WAL disks to different LUN.Data dir will be default.  /pg_${SCOPE_NAME}/mounts/data_m/"
    else
        check_disk_mount_status "$1" "$DATA_PATH"
        DATA_DISK_SIZE=$(get_disk_size "$1" "$DATA_PATH")
        if [[ -z ${DATA_DISK_SIZE} ]]; then
            checkCommandStatus "${RED}The DATA Disk ($DATA_PATH) Not Exist on server $1 please check.  exiting ${NORMAL}"
            exit -900
        else
            local SIZE_AS_GB=$(echo $((DATA_DISK_SIZE / 1024 / 1024 / 1024 )))

            if [[ -z ${GLOBAL_DATA_DISK_SIZE_AS_GB} ]]; then
                GLOBAL_DATA_DISK_SIZE_AS_GB=${SIZE_AS_GB}
                checkCommandStatus "$1:$DATA_PATH $SIZE_AS_GB GB data disk set as reference ."
            else
                local DIFF_OF_DISKS=$(echo $((GLOBAL_DATA_DISK_SIZE_AS_GB - SIZE_AS_GB)))
                if ((DIFF_OF_DISKS >= ((ACCEPTABLE_DIFF_OF_DATA_DISK_AS_GB * -1)) && DIFF_OF_DISKS <= ACCEPTABLE_DIFF_OF_DATA_DISK_AS_GB )); then
                    handle_eco "Valid disk WAL : $GLOBAL_WAL_DISK_SIZE_AS_GB   IP:$1 DIFF is :$DIFF_OF_DISKS"
                    checkCommandStatus "$1:$DATA_PATH $SIZE_AS_GB GB data disk validated."
                else
                    checkCommandStatus "$1:$DATA_PATH validation failed. DATA Disks should be same size on all servers.For more read about ACCEPTABLE_DIFF_OF_DATA_DISK_AS_GB parameter."
                    exit -900
                fi
            fi
        fi
    fi


    if [[ -z ${WAL_PATH} ]]; then
        echo ${IP} ":   ""${YELLOW}INFO:${NORMAL} WAL disk not not provided.It is recommended to seperate OS/DATA/WAL disks to different LUN.WAL dir will be default.  /pg_${SCOPE_NAME}/mounts/wal_m/"
    else
        check_disk_mount_status "$1" "$WAL_PATH"
        WAL_DISK_SIZE=$(get_disk_size "$1" "$WAL_PATH")
        if [[ -z ${WAL_DISK_SIZE} ]]; then
            checkCommandStatus "${RED}The WAL Disk ($WAL_PATH) Not Exist on server $1 please check.  exiting ${NORMAL}"
            exit -900
        else
            local SIZE_AS_GB=$(echo $((WAL_DISK_SIZE / 1024 / 1024 / 1024 )))

            if [[ -z ${GLOBAL_WAL_DISK_SIZE_AS_GB} ]]; then
                GLOBAL_WAL_DISK_SIZE_AS_GB=${SIZE_AS_GB}
                checkCommandStatus "$1:$WAL_PATH $SIZE_AS_GB GB wal disk set as reference."
            else
                local DIFF_OF_DISKS=$(echo $((GLOBAL_DATA_DISK_SIZE_AS_GB - SIZE_AS_GB)))
                if ((DIFF_OF_DISKS >= ((ACCEPTABLE_DIFF_OF_WAL_DISK_AS_GB * -1)) && DIFF_OF_DISKS <= ACCEPTABLE_DIFF_OF_WAL_DISK_AS_GB )); then
                    handle_eco "Valid disk WAL : $GLOBAL_WAL_DISK_SIZE_AS_GB   IP:$1 DIFF is :$DIFF_OF_DISKS"
                    checkCommandStatus "$1:$WAL_PATH $SIZE_AS_GB GB wal disk validated."
                else
                    checkCommandStatus "$1:$WAL_PATH validation failed. WAL Disks should be same size on all servers.For more read about ACCEPTABLE_DIFF_OF_WAL_DISK_AS_GB parameter."
                    exit -900
                fi
            fi
        fi
    fi
}

validate_env() {
  local IFS=,
  local LIST=($1)
  local GLOBAL_DATA_DISK_SIZE_AS_GB=
  local GLOBAL_WAL_DISK_SIZE_AS_GB=

  for IP in "${LIST[@]}"; do
    echo
    echo
    echo
    banner "Validation of $IP has been started."

    # install ssh keys for do not promt passwd
    install_ssh_id "$IP"

    # Check DATA and WAL disks
    validate_disks "$IP"

    # Check server connections for download packs
    checkInternetConnections "$IP"

    rm -rf  installPGCluster.log
    rsync -qaz ./installPGCluster root@"${IP}":/root/
    checkCommandStatus "Getting scripts ready : rsync"

    banner "Validation of $IP has been finished."
  done
}









FileSystemUtil(){

    local DISK_PATH=$1
    local LVM_ALIAS=$2

    createDiskAndMount(){
        echo "${DISK_PATH}1 partition creating ...";
        wipefs -aqf "${DISK_PATH}" &>> installPGCluster.log
        checkCommandStatus  "       wipefs -aqf "${DISK_PATH}""
        parted -s ${DISK_PATH} mklabel gpt &>> installPGCluster.log;
        checkCommandStatus "        mklabel gpt"
        parted -s ${DISK_PATH} "mkpart primary 1 -1" &>> installPGCluster.log;
        checkCommandStatus "        mkpart primary 1"
        parted -s ${DISK_PATH} set 1 lvm on &>> installPGCluster.log;
        checkCommandStatus "        set 1 lvm on"
        pvcreate "${DISK_PATH}1" &>> installPGCluster.log
        checkCommandStatus "        pvcreate ${DISK_PATH}1"
        vgcreate --force --yes vg_"${SCOPE_NAME}"_"${LVM_ALIAS}" "${DISK_PATH}1" &>> installPGCluster.log
        checkCommandStatus  "       vgcreate"
        lvcreate --yes --name lv_"${SCOPE_NAME}"_"${LVM_ALIAS}" -l 100%FREE vg_"${SCOPE_NAME}"_"${LVM_ALIAS}" &>> installPGCluster.log
        checkCommandStatus  "       lvcreate"
        mkfs.ext4 -F /dev/vg_"${SCOPE_NAME}"_"${LVM_ALIAS}"/lv_"${SCOPE_NAME}"_"${LVM_ALIAS}" &>> installPGCluster.log
        checkCommandStatus  "       mkfs.ext4"
        mkdir -p /pg_${SCOPE_NAME}/mounts/${LVM_ALIAS} &>> installPGCluster.log
        grep -q -F "/dev/vg_${SCOPE_NAME}"_"${LVM_ALIAS}/lv_${SCOPE_NAME}"_"${LVM_ALIAS}" /etc/fstab || echo  "/dev/vg_${SCOPE_NAME}"_"${LVM_ALIAS}/lv_${SCOPE_NAME}"_"${LVM_ALIAS} /pg_${SCOPE_NAME}/mounts/${LVM_ALIAS}/ ext4    defaults,noatime,nobarrier,discard  0   2" >> /etc/fstab
        checkCommandStatus  "       fstab entry adding"
        mount /pg_${SCOPE_NAME}/mounts/${LVM_ALIAS}  &>> installPGCluster.log
        checkCommandStatus  "       /pg_${SCOPE_NAME}/mounts/${LVM_ALIAS} mount"
        chown -R postgres:postgres /pg_${SCOPE_NAME}/mounts/${LVM_ALIAS}
        checkCommandStatus  "       /pg_${SCOPE_NAME}/mounts/${LVM_ALIAS} owner change to postgres."

        # test disk
        dd if=/dev/zero of=/pg_${SCOPE_NAME}/mounts/${LVM_ALIAS}/file.txt count=10 bs=1024 &>> installPGCluster.log
        checkCommandStatus  "       Writing test file /pg_${SCOPE_NAME}/mounts/${LVM_ALIAS}/file.txt"
        rm -rf /pg_${SCOPE_NAME}/mounts/${LVM_ALIAS}/file.txt
    }

    if [[ $(partprobe -d -s ${DISK_PATH} | grep 'partitions') = "" ]]; then
        createDiskAndMount
    else
        read lv_name vg_name partition_p <<< $(lvs --noheadings   -o lv_name,vg_name,devices | grep "${DISK_PATH}" | awk -F"|" '{print $1" "$2" "$3}');
        checkCommandStatus  "      extract lvm_name:${lv_name}"
        if [[ ${lv_name} ]] ; then
            #lvremove --force --yes ${vg_name} &>> installPGCluster.log ;
            #checkCommandStatus  "      lvremove --force --yes ${vg_name}"
            vgremove --force --yes ${vg_name} &>> installPGCluster.log ;
            checkCommandStatus  "      vgremove --force --yes ${vg_name}"
            parted -s "${DISK_PATH}" rm 1;
            checkCommandStatus  "      dd if=/dev/zero"
            wipefs -aqf "${DISK_PATH}" &>> installPGCluster.log;
            checkCommandStatus  "      wipefs -aqf "${DISK_PATH}""
            createDiskAndMount
        else
            echo  "lvm_name coluld not extract maybe not LVM volume. Please handle disk ${DISK_PATH} yourself. It has partition but it should not have."
            dd if=/dev/zero of="${DISK_PATH}" bs=512 count=1           #parted -s "${DISK_PATH}" rm 1;
            checkCommandStatus  "      dd if=/dev/zero"
            wipefs -aqf "${DISK_PATH}" &>> installPGCluster.log;
            checkCommandStatus  "      wipefs -aqf "${DISK_PATH}""
            createDiskAndMount
        fi
    fi
}

CentOsPacksInstallerAndKernel(){

    systemctl enable ntpdate.service
    checkCommandStatus "Enable ntpdate service"
    systemctl start ntpdate.service
    checkCommandStatus "Start ntpdate service"

    yum install epel-release -y  >&-
    checkCommandStatus "Enable epel-release repo"

    yum update -y  >&-
    checkCommandStatus "Updating CentOS packs"

    yum install gcc rsync telnet -y  >&-
    checkCommandStatus "gcc"

    yum -y install python python-devel libyaml  >&-
    checkCommandStatus "Install sshpass python"


    # Python PIP install
    wget -q --output-document="./get-pip.py" https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
    checkCommandStatus "Download PIP"
    sudo python ./get-pip.py  >&-
    checkCommandStatus "Installing python PIP"
    rm ./get-pip.py


    # Postgres server repo add
    # TODO  NOT WORK check later   yum install http://download.postgresql.org/pub/repos/yum/11/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    wget -q --output-document="./pgdg-redhat-repo-latest.noarch.rpm" http://download.postgresql.org/pub/repos/yum/11/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    checkCommandStatus "PG11 Repo Download RPM"
    sudo yum install ./pgdg-redhat-repo-latest.noarch.rpm -y >&-
    rm ./pgdg-redhat-repo-latest.noarch.rpm


    # Postgres install to server
    sudo yum groupinstall "PostgreSQL Database Server 11 PGDG" -y >&-
    checkCommandStatus "Installing PostgreSQL Database Server 11 PGDG"
    # Postgres tools install
    sudo yum install pg_activity pg_badger -y  >&-
    checkCommandStatus "Installing pg_activity pg_badger"


    sed -i -e 's#SELINUX=enforcing#'"SELINUX=disabled"'#g' /etc/selinux/config;
    checkCommandStatus "Disable SELINUX"


    create_tuned_profile_and_activate(){


    page_size=$( getconf PAGE_SIZE )
    phys_pages=$(getconf _PHYS_PAGES )
    shmall=$( expr $phys_pages / 2)
    shmmax=$( expr $shmall \* $page_size)

    mkdir -p /etc/tuned/postgresql-tuned
    echo '[main]
    include = throughput-performance
    summary = For excellent PostgreSQL database workload performance

    [disk]
    readahead = 4096

    [sysctl]
    kernel.shmmax = '"${shmmax}"'
    kernel.shmall = '"${shmall}"'
    kernel.shmmni = 4096
    kernel.sem = 512 64000 100 2048

    fs.file-max = 2097152

    # 64MB & wcache or 8MB & 64MB
    vm.dirty_background_ratio = 0
    vm.dirty_background_bytes = 67108864

    vm.dirty_ratio = 0
    vm.dirty_bytes = 1073741824

    # must be lower
    vm.dirty_expire_centisecs = 3000
    vm.dirty_writeback_centisecs = 500

    vm.swappiness = 0
    vm.overcommit_memory = 2
    vm.overcommit_ratio = 80

    vm.zone_reclaim_mode = 0
    kernel.numa_balancing = 0

    kernel.sched_min_granularity_ns = 2000000
    kernel.sched_latency_ns = 10000000
    kernel.sched_wakeup_granularity_ns = 3000000 # < (sched_latency_ns / 2)
    kernel.sched_migration_cost_ns = 5000000
    kernel.sched_autogroup_enabled = 0

    #  vm.nr_hugepages = <total ram / 2 olacak şekilde, sb den daha da büyük olacak şekilde>
    vm.hugetlb_shm_group = 26
    vm.hugepages_treat_as_movable = 0
    vm.nr_overcommit_hugepages = 512' > "/etc/tuned/postgresql-tuned/tuned.conf"

    tuned-adm profile postgresql-tuned  >&-
    tuned-adm active  >&-

    checkCommandStatus "postgresql-tuned added"

    }

    create_disabler_and_activate(){
        echo '[Unit]
        Description=Disable Transparent Huge Pages (THP)
        Before='"patroni_${SCOPE_NAME}.service"'

        [Service]
        Type=notify

        ExecStart=/bin/bash -c '"'"'echo never > /sys/kernel/mm/transparent_hugepage/enabled && echo never > /sys/kernel/mm/transparent_hugepage/defrag; while true; do grep -q "\[never\]" /sys/kernel/mm/transparent_hugepage/enabled; check1=$?; grep -q "\[never\]" /sys/kernel/mm/transparent_hugepage/defrag; check2=$?; if (( check1 + check2 )); then echo waiting; sleep 1; else echo succeed; break; fi done; /bin/systemd-notify --ready'"'"'

        RemainAfterExit=true

        [Install]
        WantedBy=multi-user.target' > /etc/systemd/system/postgresql-thp-disabler.service

        systemctl enable postgresql-thp-disabler
        systemctl start postgresql-thp-disabler

        checkCommandStatus "postgresql-thp-disabler added to services"

    }

    create_watchdog_and_activate(){
        echo '[Unit]
Description=Makes kernel watchdog device available for Patroni

[Service]
Type=oneshot

Environment=WATCHDOG_MODULE=softdog
Environment=WATCHDOG_DEVICE=/dev/watchdog
Environment=PATRONI_USER=postgres

ExecStart=/usr/sbin/modprobe ${WATCHDOG_MODULE}
ExecStart=/bin/chown ${PATRONI_USER} ${WATCHDOG_DEVICE}

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/watchdog.service

        systemctl enable watchdog.service
        systemctl start watchdog.service

        checkCommandStatus "watchdog.service added to services"

    }

    adjust_sysctl_and_limits(){

        grep -q -F 'kernel.sem' /etc/sysctl.conf || echo 'kernel.sem = 250 512000 100 2048' >> /etc/sysctl.conf
        grep -q -F 'fs.file-max' /etc/sysctl.conf || echo 'fs.file-max = 1000000' >> /etc/sysctl.conf
        grep -q -F 'net.ipv4.ip_local_port_range' /etc/sysctl.conf || echo 'net.ipv4.ip_local_port_range = 1024 65000' >> /etc/sysctl.conf
        grep -q -F 'net.core.rmem_default' /etc/sysctl.conf || echo 'net.core.rmem_default = 1048576' >> /etc/sysctl.conf
        grep -q -F 'net.core.rmem_max' /etc/sysctl.conf || echo 'net.core.rmem_max = 1048576' >> /etc/sysctl.conf
        grep -q -F 'net.core.wmem_default' /etc/sysctl.conf || echo 'net.core.wmem_default = 262144' >> /etc/sysctl.conf
        grep -q -F 'net.core.wmem_max' /etc/sysctl.conf || echo 'net.core.wmem_max = 262144' >> /etc/sysctl.conf

        checkCommandStatus "sysctl adjusting"

        # Limits
        grep -q -F 'root        soft    nofile    1000000' /etc/security/limits.conf || echo 'root        soft    nofile    1000000' >> /etc/security/limits.conf
        grep -q -F 'root        hard    nofile    1000000' /etc/security/limits.conf || echo 'root        hard    nofile    1000000' >> /etc/security/limits.conf
        grep -q -F 'postgres        soft    nofile    1000000' /etc/security/limits.conf || echo 'postgres        soft    nofile    1000000' >> /etc/security/limits.conf
        grep -q -F 'postgres        hard    nofile    1000000' /etc/security/limits.conf || echo 'postgres        hard    nofile    1000000' >> /etc/security/limits.conf
        grep -q -F 'postgres    soft    memlock   274877906944' /etc/security/limits.conf || echo 'postgres    soft    memlock   274877906944' >> /etc/security/limits.conf
        grep -q -F 'postgres    hard    memlock   274877906944' /etc/security/limits.conf || echo 'postgres    hard    memlock   274877906944' >> /etc/security/limits.conf
        grep -q -F 'postgres    soft    nproc  131072' /etc/security/limits.conf  || echo 'postgres    	soft    nproc  131072' >> /etc/security/limits.conf
        grep -q -F 'postgres    nproc  131072' /etc/security/limits.conf  || echo 'postgres    	hard    nproc  131072' >> /etc/security/limits.conf

        checkCommandStatus "limits.conf adjusting"
    }

    setup_disks(){

        # Data Disk operation
        if [[ -z ${DATA_PATH} ]]; then
            mkdir -p  /pg_${SCOPE_NAME}/mounts/data_m/
            chown -R postgres:postgres /pg_${SCOPE_NAME}
            chmod 700 /pg_${SCOPE_NAME}/mounts/data_m/
        else
            echo ""
            echo ""
            echo ${IP} ":   ""${GREEN}Data Disk ${DATA_PATH} processing ....${NORMAL}"
            FileSystemUtil "${DATA_PATH}" "data_m"
            checkCommandStatus "Data Disk Partition : ${DATA_PATH} "
        fi


        # WAL Disk operation
        if [[ -z ${WAL_PATH} ]]; then
            mkdir -p  /pg_${SCOPE_NAME}/mounts/wal_m/
            chown -R postgres:postgres /pg_${SCOPE_NAME}
            chmod 700 /pg_${SCOPE_NAME}/mounts/wal_m/
        else
           echo ""
           echo ""
           echo ${IP} ":   ""${GREEN}WAL Disk ${WAL_PATH} processing ....${NORMAL}"
           FileSystemUtil "${WAL_PATH}" "wal_m"
           checkCommandStatus "WAL Disk Partition: ${WAL_PATH}"
        fi

    }

    enable_firewall(){
       systemctl enable firewalld
       checkCommandStatus "Enable firewalld"
       systemctl start firewalld
       checkCommandStatus "Start firewalld"

    }

    enable_firewall;
    create_tuned_profile_and_activate;
    create_disabler_and_activate;
    create_watchdog_and_activate;
    adjust_sysctl_and_limits;
    setup_disks;
}

EtcdInstaller(){

    check_etcd_status(){
        ssh -q -oStrictHostKeyChecking=no root@$1 2>> installPGCluster.log  'bash -s' <<-'ENDSSH'
            etcdctl cluster-health
ENDSSH
    }

    adjust_firewall_etcd(){
          for i in "${!LIST[@]}"
          do
                FIREWALL_SERVER_IP=${LIST[$i]}
                ssh -q -oStrictHostKeyChecking=no root@${SERVER_IP} FIREWALL_SERVER_IP=${FIREWALL_SERVER_IP} 2>> installPGCluster.log SERVER_IP=${SERVER_IP} 'bash -s' <<-'ENDSSH'
                firewall-cmd --permanent --zone=public --add-rich-rule="rule family=ipv4 source address=${FIREWALL_SERVER_IP}/32 port protocol=tcp port=2380 accept"  >&-
                firewall-cmd --permanent --zone=public --add-rich-rule="rule family=ipv4 source address=${FIREWALL_SERVER_IP}/32 port protocol=tcp port=2379 accept"  >&-
ENDSSH
          done
    }



    start_setup_etcd() {
      local IFS=,
      local LIST=($1)
      local ETCD_INITIAL_CLUSTER=""
      local IFS=$'\n'

      # FILL CLUSTER STRING
      for i in "${!LIST[@]}"
      do
       SERVER_ORDER_NUMBER=$(echo $(( ${i}+1 )))
       NAME="etcd"${SERVER_ORDER_NUMBER}
       SERVER_IP=${LIST[$i]}
       if [[ ${i} != 0 ]]; then
              ETCD_INITIAL_CLUSTER="${ETCD_INITIAL_CLUSTER},"
       fi
       ETCD_INITIAL_CLUSTER=${ETCD_INITIAL_CLUSTER}${NAME}"=http://"${SERVER_IP}":2380"
       adjust_firewall_etcd ${SERVER_IP}
      done


      for i in "${!LIST[@]}"
      do
       SERVER_ORDER_NUMBER=$(echo $(( ${i}+1 )))
       NAME="etcd"${SERVER_ORDER_NUMBER}
       SERVER_IP=${LIST[$i]}

       ssh -oStrictHostKeyChecking=no root@"${SERVER_IP}"  NAME=${NAME} SERVER_IP=${SERVER_IP} SCOPE_NAME=${SCOPE_NAME} ETCD_INITIAL_CLUSTER=${ETCD_INITIAL_CLUSTER}  2>> installPGCluster.log 'bash -s' <<-'ENDSSH'
            check_program_exist()
            {
              command -v "$1" >/dev/null 2>&1
            }

            checkCommandStatus(){
                if [[ $? -eq 0 ]]; then
                    echo "${SERVER_IP} :$1..etcd_install....."${GREEN}"OK${NORMAL}";
                else
                    echo "${SERVER_IP} :$1..etcd_install....."${RED}"FAILED_"$?"${NORMAL}";
                    exit -901
                fi
            }

            if check_program_exist etcd; then
                checkCommandStatus "etcd already installed skip it"
            else

                ### For now only CentOS >= 7.5
                if [[ -f "/etc/centos-release" ]]; then
                    yum install etcd -y  >&-
                    checkCommandStatus "etcd yum installed"
                else
                    echo "$SERVER_IP..etcd_install....Not Supported OS Type Only CentOS 7.5 and upper supported"
                    exit -902
                fi


                mv /etc/etcd/etcd.conf /etc/etcd/etcd.conf.orjinal
                checkCommandStatus "Moving orjinal conf file"

                echo '#[Member]
    ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
    ETCD_LISTEN_PEER_URLS="http://'${SERVER_IP}':2380"
    ETCD_LISTEN_CLIENT_URLS="http://'${SERVER_IP}':2379,http://127.0.0.1:2379"
    ETCD_NAME="'${NAME}'"
    #[Clustering]
    ETCD_INITIAL_ADVERTISE_PEER_URLS="http://'${SERVER_IP}':2380"
    ETCD_ADVERTISE_CLIENT_URLS="http://'${SERVER_IP}':2379"
    ETCD_INITIAL_CLUSTER="'${ETCD_INITIAL_CLUSTER}'"
    ETCD_INITIAL_CLUSTER_TOKEN="'${SCOPE_NAME}'_CLS"
    ETCD_INITIAL_CLUSTER_STATE="new"' > /etc/etcd/etcd.conf

               checkCommandStatus "Write new conf file"
            fi
ENDSSH

      done

      for i in "${!LIST[@]}"
      do
       SERVER_ORDER_NUMBER=$(echo $(( ${i}+1 )))
       NAME="etcd"${SERVER_ORDER_NUMBER}
       SERVER_IP=${LIST[$i]}

       ssh -oStrictHostKeyChecking=no root@"${SERVER_IP}" SERVER_IP=${SERVER_IP} 2>> installPGCluster.log 'bash -s' <<-'ENDSSH'
            checkCommandStatus(){
                if [[ $? -eq 0 ]]; then
                    echo "${SERVER_IP} :$1..etcd_install....."${GREEN}"OK${NORMAL}";
                else
                    echo "${SERVER_IP} :$1..etcd_install....."${RED}"FAILED_"$?"${NORMAL}";
                    exit -901
                fi
            }

            firewall-cmd --reload >&-
            systemctl restart firewalld >&-

            systemctl enable etcd
            systemctl start etcd &
            checkCommandStatus "Starting etcd ..."
ENDSSH

      done



    }

    start_setup_etcd ${IP_LIST_OF_CLUSTER}

    ETCDCTL_API=3 etcdctl user add root:${ETCD_PASSWORD}
    checkCommandStatus "etcd 3 add user"
    ETCDCTL_API=3 etcdctl auth enable
    checkCommandStatus "etcd 3 enable auth"
    ETCDCTL_API=3 etcdctl --endpoints=http://127.0.0.1:2379 --user="root:${ETCD_PASSWORD}" role remove guest >&-
    checkCommandStatus "etcd 3 remove roles"

    ETCDCTL_API=2 etcdctl user add root:${ETCD_PASSWORD}
    checkCommandStatus "etcd 2 add user"
    ETCDCTL_API=2 etcdctl auth enable
    checkCommandStatus "etcd 2 enable auth"
    ETCDCTL_API=2 etcdctl --endpoints=http://127.0.0.1:2379 --u "root:${ETCD_PASSWORD}" role remove guest
    checkCommandStatus "etcd 2 remove roles"

    for i in "${!LIST[@]}"
      do
       SERVER_ORDER_NUMBER=$(echo $(( ${i}+1 )))
       NAME="etcd"${SERVER_ORDER_NUMBER}
       SERVER_IP=${LIST[$i]}

       ssh -oStrictHostKeyChecking=no root@"${SERVER_IP}" SERVER_IP=${SERVER_IP} 2>> installPGCluster.log 'bash -s' <<-'ENDSSH'
            checkCommandStatus(){
                if [[ $? -eq 0 ]]; then
                    echo "${SERVER_IP} :$1..etcd_install....."${GREEN}"OK${NORMAL}";
                else
                    echo "${SERVER_IP} :$1..etcd_install....."${RED}"FAILED_"$?"${NORMAL}";
                    exit -901
                fi
            }
            systemctl restart etcd &
            checkCommandStatus "Restarting etcd ..."
ENDSSH

      done

    for i in "${!LIST[@]}"
    do
       SERVER_IP=${LIST[$i]}
       checkCommandStatus "Etcd status checking" check_etcd_status ${SERVER_IP}
       break;
    done

}

create_master_template(){

    ${ETCD_PASSWORD}

    ssh -oStrictHostKeyChecking=no root@${1} SERVER_IP=${1} SCOPE_NAME=${2} PG_PORT=${PG_PORT}  ETCD_PASSWORD=${ETCD_PASSWORD} 2>> installPGCluster.log 'bash -s' <<-'ENDSSH'
 echo 'scope: SCOPE_NAME
namespace: NAME_SPACE
name: NAME_OF_INSTANCE

restapi:
  listen: SERVER_IP:8008
  connect_address: SERVER_IP:8008
#  certfile: /etc/ssl/certs/ssl-cert-snakeoil.pem
#  keyfile: /etc/ssl/private/ssl-cert-snakeoil.key
#  authentication:
#    username: test
#    password: test

# ctl:
#   insecure: false # Allow connections to SSL sites without certs
#   certfile: /etc/ssl/certs/ssl-cert-snakeoil.pem
#   cacert: /etc/ssl/certs/ssl-cacert-snakeoil.pem

etcd:
    use_proxies: false
    hosts: ETCD_INITIAL_CLUSTER
    protocol: http
    username: root
    password: ETCD_PASSWORD


bootstrap:
  # this section will be written into Etcd:/<namespace>/<scope>/config after initializing new cluster
  # and all other cluster members will use it as a `global configuration`
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
#    master_start_timeout: 300
#    synchronous_mode: false
    #standby_cluster:
      #host: 127.0.0.1
      #port: 1111
      #primary_slot_name: patroni
    postgresql:
      use_pg_rewind: true
#      use_slots: true
      parameters:
#        wal_level: hot_standby
#        hot_standby: "on"
#        wal_keep_segments: 8
#        max_wal_senders: 10
#        max_replication_slots: 10
#        wal_log_hints: "on"
#        archive_mode: "on"
#        archive_timeout: 1800s
#        archive_command: mkdir -p ../wal_archive && test ! -f ../wal_archive/%f && cp %p ../wal_archive/%f
#      recovery_conf:
#        restore_command: cp ../wal_archive/%f %p

  # some desired options for 'initdb'
  initdb:  # Note: It needs to be a list (some options need values, others are switches)
  - encoding: UTF8
  - waldir=PG_WAL_PATH
  - data-checksums

  pg_hba:  # Add following lines to pg_hba.conf after running 'initdb'
  # For kerberos gss based connectivity (discard @.*$)
  #- host replication replicator 127.0.0.1/32 gss include_realm=0
  #- host all all 0.0.0.0/0 gss include_realm=0
  - host replication replicator 0.0.0.0/0 md5
  - host all all 0.0.0.0/0 md5
#  - hostssl all all 0.0.0.0/0 md5

  # Additional script to be launched after initial cluster creation (will be passed the connection URL as parameter)
# post_init: /usr/local/bin/setup_cluster.sh

  # Some additional users users which needs to be created after initializing new cluster
  users:
    admin:
      password: admin
      options:
        - createrole
        - createdb

postgresql:
  listen: SERVER_IP:PG_PORT
  connect_address: SERVER_IP:PG_PORT
  data_dir: PG_DATA_DIR
  bin_dir: PG_BIN_DIR
#  config_dir:
  pgpass: /tmp/pgpass0
  authentication:
    replication:
      username: replicator
      password: REPLICATION_USER_PASSWORD
    superuser:
      username: postgres
      password: PG_SUPER_USER_PASSWORD
    rewind:  # Has no effect on postgres 10 and lower
      username: rewind_prod
      password: PG_SUPER_USER_PASSWORD
  # Server side kerberos spn
#  krbsrvname: postgres
  parameters:
    # Fully qualified kerberos ticket file for the running user
    # same as KRB5CCNAME used by the GSS
#   krb_server_keyfile: /var/spool/keytabs/postgres
    unix_socket_directories: '.'

#watchdog:
#  mode: automatic # Allowed values: off, automatic, required
#  device: /dev/watchdog
#  safety_margin: 5

tags:
    nofailover: false
    noloadbalance: false
    clonefrom: false
    nosync: false' > "/etc/patroni_${SCOPE_NAME}.yml"
ENDSSH


}

InstallPatroni(){

        check_patroni_status(){
            echo $(
            ssh -q -oStrictHostKeyChecking=no root@$1 SCOPE_NAME=${SCOPE_NAME} 2>> installPGCluster.log  'bash -s' <<-'ENDSSH'
                patronictl -c "/etc/patroni_${SCOPE_NAME}.yml" list ${SCOPE_NAME}
ENDSSH
)
        }

        adjust_firewallPatroni(){
          for i in "${!LIST[@]}"
          do
                FIREWALL_SERVER_IP=${LIST[$i]}
                ssh -q -oStrictHostKeyChecking=no root@${SERVER_IP} FIREWALL_SERVER_IP=${FIREWALL_SERVER_IP} 2>> installPGCluster.log SERVER_IP=${SERVER_IP} PG_PORT=${PG_PORT} 'bash -s' <<-'ENDSSH'
                firewall-cmd --permanent --zone=public --add-rich-rule="rule family=ipv4 source address=${FIREWALL_SERVER_IP}/32 port protocol=tcp port=8008 accept"  >&-
                firewall-cmd --permanent --zone=public --add-rich-rule="rule family=ipv4 source address=${FIREWALL_SERVER_IP}/32 port protocol=tcp port=${PG_PORT} accept"  >&-
ENDSSH
          done
        }

        start_setup_patroni() {
          local IFS=,
          local LIST=(${IP_LIST_OF_CLUSTER})
          local IFS=$'\n'
          local ETCD_INITIAL_CLUSTER=

          # FILL CLUSTER STRING
          for i in "${!LIST[@]}"
          do
           SERVER_ORDER_NUMBER=$(echo $(( ${i}+1 )))
           local SERVER_IP=${LIST[$i]}
           if [[ ${i} != 0 ]]; then
                  ETCD_INITIAL_CLUSTER="${ETCD_INITIAL_CLUSTER},"
           fi
           ETCD_INITIAL_CLUSTER=${ETCD_INITIAL_CLUSTER}${SERVER_IP}":2379"
           adjust_firewallPatroni
          done


          if [[ -z ${DSC_ROOT_PATH} ]];
          then
             echo "DSC_ROOT_PATH not provided.We will use default."
             DSC_ROOT_PATH="PG_$SCOPE_NAME"
          fi


          for i in "${!LIST[@]}"
          do
           SERVER_ORDER_NUMBER=$(echo $(( ${i}+1 )))
           SERVER_IP=${LIST[$i]}
           NAME="patroni_"${SERVER_ORDER_NUMBER}"_${SERVER_IP}"

           create_master_template ${SERVER_IP} ${SCOPE_NAME}
           checkCommandStatus "Patroni create template conf to ${SERVER_IP} "

           ssh -oStrictHostKeyChecking=no root@"${SERVER_IP}"  NAME=${NAME} SERVER_IP=${SERVER_IP} SCOPE_NAME=${SCOPE_NAME} NAMESPACE=${DSC_ROOT_PATH} ETCD_INITIAL_CLUSTER="${ETCD_INITIAL_CLUSTER}" WAL_PATH="/pg_${SCOPE_NAME}/mounts/wal_m/wal" DATA_PATH="/pg_${SCOPE_NAME}/mounts/data_m/data" PG_BIN_DIR="/usr/pgsql-11/bin" PG_PORT=${PG_PORT} ETCD_PASSWORD=${ETCD_PASSWORD} 'bash -s' <<-'ENDSSH'

                check_program_exist()
                {
                  command -v "$1" >/dev/null 2>&1
                }

                checkCommandStatus(){
                    if [[ $? -eq 0 ]]; then
                        echo "${SERVER_IP} :$1..patroni_install....."${GREEN}"OK${NORMAL}";
                    else
                        echo "${SERVER_IP} :$1..patroni_install....."${RED}"FAILED_"$?"${NORMAL}";
                        exit -901
                    fi
                }

                if check_program_exist patroni; then
                    checkCommandStatus "patroni already installed skip it"
                else

                    # Patroni install with pip
                    pip -q install patroni[etcd]
                    checkCommandStatus "Installing Patroni"
                fi

                sed -i -e 's#SCOPE_NAME#'"${SCOPE_NAME}"'#g' "/etc/patroni_${SCOPE_NAME}.yml";
                sed -i -e 's#NAME_SPACE#'"${NAMESPACE}"'#g' "/etc/patroni_${SCOPE_NAME}.yml";
                sed -i -e 's#NAME_OF_INSTANCE#'"${NAME}"'#g' "/etc/patroni_${SCOPE_NAME}.yml";
                sed -i -e 's#SERVER_IP#'"${SERVER_IP}"'#g' "/etc/patroni_${SCOPE_NAME}.yml";
                sed -i -e 's#ETCD_INITIAL_CLUSTER#'"${ETCD_INITIAL_CLUSTER}"'#g' "/etc/patroni_${SCOPE_NAME}.yml";
                sed -i -e 's#PG_WAL_PATH#'"${WAL_PATH}"'#g' "/etc/patroni_${SCOPE_NAME}.yml";
                sed -i -e 's#PG_DATA_DIR#'"${DATA_PATH}"'#g' "/etc/patroni_${SCOPE_NAME}.yml";
                sed -i -e 's#PG_BIN_DIR#'"${PG_BIN_DIR}"'#g' "/etc/patroni_${SCOPE_NAME}.yml";
                sed -i -e 's#PG_PORT#'"${PG_PORT}"'#g' "/etc/patroni_${SCOPE_NAME}.yml";
                sed -i -e 's#ETCD_PASSWORD#'"${ETCD_PASSWORD}"'#g' "/etc/patroni_${SCOPE_NAME}.yml";
                sed -i -e 's#REPLICATION_USER_PASSWORD#'"${REPLICATION_USER_PASSWORD}"'#g' "/etc/patroni_${SCOPE_NAME}.yml";
                sed -i -e 's#PG_SUPER_USER_PASSWORD#'"${PG_SUPER_USER_PASSWORD}"'#g' "/etc/patroni_${SCOPE_NAME}.yml";


                echo '# This is an example systemd config file for Patroni
        # You can copy it to "/etc/systemd/system/patroni.service",

        [Unit]
        Description=Runners to orchestrate a high-availability PostgreSQL
        After=syslog.target network.target

        [Service]
        Type=simple

        User=postgres
        Group=postgres

        # Read in configuration file if it exists, otherwise proceed
        EnvironmentFile=-/etc/patroni_env.conf

        WorkingDirectory=~

        # Where to send early-startup messages from the server
        # This is normally controlled by the global default set by systemd
        #StandardOutput=syslog

        # Pre-commands to start watchdog device
        # Uncomment if watchdog is part of your patroni setup
        #ExecStartPre=-/usr/bin/sudo /sbin/modprobe softdog
        #ExecStartPre=-/usr/bin/sudo /bin/chown postgres /dev/watchdog

        # Start the patroni process
        ExecStart=/bin/patroni '"/etc/patroni_${SCOPE_NAME}.yml"'

        # Send HUP to reload from patroni.yml
        ExecReload=/bin/kill -s HUP $MAINPID

        # only kill the patroni process, not its children, so it will gracefully stop postgres
        KillMode=process

        # Give a reasonable amount of time for the server to start up/shut down
        TimeoutSec=30

        # Do not restart the service if it crashes, we want to manually inspect database on failure
        Restart=no

        [Install]
        WantedBy=multi-user.target' > /etc/systemd/system/patroni_${SCOPE_NAME}.service

        firewall-cmd --reload >&-
        systemctl restart firewalld >&-

        systemctl enable patroni_${SCOPE_NAME}.service
        systemctl start patroni_${SCOPE_NAME}.service
        checkCommandStatus "Patroni Start"
ENDSSH






        done



       }

       start_setup_patroni

       for i in "${!LIST[@]}"
       do
          SERVER_IP=${LIST[$i]}
          checkCommandStatus "Patroni status checking" check_patroni_status
          break;
       done


}



cent_os_env_installer() {

  local IFS=,
  local LIST=($1)
  local IFS=$'\n'

  for IP in "${LIST[@]}"; do

    banner "$IP CentOS Package and Kernel started."

    ssh -oStrictHostKeyChecking=no root@"${IP}" IP=${IP} SCOPE_NAME=${SCOPE_NAME} DATA_PATH=${DATA_PATH} WAL_PATH=${WAL_PATH} DSC_ROOT_PATH=${DSC_ROOT_PATH} PG_PORT=${PG_PORT} ETCD_PASSWORD=${ETCD_PASSWORD} REPLICATION_USER_PASSWORD=${REPLICATION_USER_PASSWORD} PG_SUPER_USER_PASSWORD=${PG_SUPER_USER_PASSWORD} 2>> installPGCluster.log 'bash -s' <<-'ENDSSH'
    /root/installPGCluster -n "NOT_NEED" -p "NOT_NEED" -s "${SCOPE_NAME}" -d "${DATA_PATH}" -w "${WAL_PATH}" -e "${DSC_ROOT_PATH}" -k "${PG_PORT}" -g ${ETCD_PASSWORD} -t ${REPLICATION_USER_PASSWORD} -y ${PG_SUPER_USER_PASSWORD} -x 1
    if [[ $? -eq 0 ]]; then
            echo "system..install....."${GREEN}"OK${NORMAL}";
        else
            echo "system..install....."${RED}"FAILED_"$?"${NORMAL}";
            exit -903
    fi
ENDSSH
    checkCommandStatus
    banner "$IP CentOS Package and Kernel finished."
  done


  /root/installPGCluster -n "NOT_NEED" -p ${IP_LIST_OF_CLUSTER} -s "${SCOPE_NAME}" -d "${DATA_PATH}" -w "${WAL_PATH}" -e "${DSC_ROOT_PATH}" -k "${PG_PORT}" -g ${ETCD_PASSWORD}  -t ${REPLICATION_USER_PASSWORD} -y ${PG_SUPER_USER_PASSWORD} -x 2
  checkCommandStatus
  /root/installPGCluster -n "NOT_NEED" -p ${IP_LIST_OF_CLUSTER} -s "${SCOPE_NAME}" -d "${DATA_PATH}" -w "${WAL_PATH}" -e "${DSC_ROOT_PATH}" -k "${PG_PORT}" -g ${ETCD_PASSWORD}  -t ${REPLICATION_USER_PASSWORD} -y ${PG_SUPER_USER_PASSWORD} -x 3
  checkCommandStatus

}

### For now only CentOS >= 7.5
if [[ -f "/etc/centos-release" ]]; then
    # Install OS packs

    checkCommandStatus "RUN_LEVEL ... ${RUN_LEVEL}"

    if [[ -z ${RUN_LEVEL} ]] ;then
        validate_env "${IP_LIST_OF_CLUSTER}"
        checkCommandStatus
        cent_os_env_installer "${IP_LIST_OF_CLUSTER}"
        checkCommandStatus
    elif [[ ${RUN_LEVEL} == 1 ]] ;then
        CentOsPacksInstallerAndKernel
        checkCommandStatus
    elif [[ ${RUN_LEVEL} == 2 ]] ;then

         # INSTALL ETCD dcs Cluster OS types evaluate in it.
         banner "ETCD setup has been started."
         EtcdInstaller
         checkCommandStatus "ETCD ... finished ..."
         banner "ETCD setup has been finished."

    elif [[ ${RUN_LEVEL} == 3 ]] ;then

         # INSTALL Patroni Cluster OS types evaluate in it.
         banner "Patroni setup has been started."
         InstallPatroni
         checkCommandStatus "Patroni ... finished ..."
         banner "Patroni setup has been finished."
    fi
else
    echo "Not Supported OS Type Only CentOS 7.5 and upper supported"
    exit -902
fi