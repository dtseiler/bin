#!/bin/bash

#
# This script will set up a PostgreSQL 10 master/replica cluster on one machine. The master
# and replica will each reside in separate data directories and listen on # different ports.
#
# Must be run as user with sudo access
#

#
# Define our environment
#
MASTER_PGDATA=/var/lib/pgsql/10/master_data
MASTER_PGPORT=5432
REPLICA_PGDATA=/var/lib/pgsql/10/replica_data
REPLICA_PGPORT=5433
WAL_ARCHIVE_DIRECTORY=/var/lib/pgsql/wal_archive
BACKUP_DIRECTORY=/tmp/pgbackup/

#
# TEAR DOWN / RESET
#
if sudo [ -d $REPLICA_PGDATA ]; then
	sudo su -l postgres -c "/usr/pgsql-10/bin/pg_ctl -D $REPLICA_PGDATA stop -m fast"
	sudo rm -rf $REPLICA_PGDATA
fi
if sudo [ -d $MASTER_PGDATA ]; then
	sudo su -l postgres -c "/usr/pgsql-10/bin/pg_ctl -D $MASTER_PGDATA stop -m fast"
	sudo rm -rf $MASTER_PGDATA
fi
if sudo [ -d $WAL_ARCHIVE_DIRECTORY ]; then
	sudo rm -rf $WAL_ARCHIVE_DIRECTORY
fi


#
# Prepare the environment
#
sudo su -l postgres -c "mkdir -p $MASTER_PGDATA && chmod 700 $MASTER_PGDATA"
sudo su -l postgres -c "mkdir -p $REPLICA_PGDATA && chmod 700 $REPLICA_PGDATA"
sudo su -l postgres -c "mkdir -p $WAL_ARCHIVE_DIRECTORY"

# May need to allow the two PGPORTs in the firewall here (tcp)

#
# Install PDGD repo for PostgreSQL 10 packages
#
sudo rpm -Uvh https://download.postgresql.org/pub/repos/yum/10/redhat/rhel-7-x86_64/pgdg-centos10-10-2.noarch.rpm
sudo yum install -y postgresql10-server postgresql10-contrib

# Option: set the postgresql binaries in the postgres user's path
sudo su -l postgres -c "echo 'export PATH=/usr/pgsql-10/bin:\$PATH' >> /var/lib/pgsql/.pgsql_profile"

#
# Initialize primary database
#
sudo su -l postgres -c "/usr/pgsql-10/bin/initdb -D $MASTER_PGDATA"
sudo su -l postgres -c "/usr/pgsql-10/bin/pg_ctl -D $MASTER_PGDATA start -w"

#
# Prepare primary for replication
#

# Create replication user and configure .pgpass (must be 0600)
sudo su -l postgres -c "psql -c \"CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD 'replicate123';\""
sudo su -l postgres -c "echo \"127.0.0.1:*:*:replicator:replicate123\" >> /var/lib/pgsql/.pgpass"
sudo chmod 0600 /var/lib/pgsql/.pgpass


# Set replication configurations
sudo su -l postgres -c "echo \"port = $MASTER_PGPORT\" >> $MASTER_PGDATA/postgresql.conf"
sudo su -l postgres -c "echo \"wal_level = replica\" >> $MASTER_PGDATA/postgresql.conf"
sudo su -l postgres -c "echo \"max_wal_senders = 10\" >> $MASTER_PGDATA/postgresql.conf"
sudo su -l postgres -c "echo \"wal_keep_segments = 64\" >> $MASTER_PGDATA/postgresql.conf"
sudo su -l postgres -c "echo \"archive_mode = on\" >> $MASTER_PGDATA/postgresql.conf"
# Just using cp for a quick test. For production a more robust tool (eg pgBackRest) should be used
sudo su -l postgres -c "echo \"archive_command = 'test ! -f $WAL_ARCHIVE_DIRECTORY/%f && cp %p $WAL_ARCHIVE_DIRECTORY/%f'\" >> $MASTER_PGDATA/postgresql.conf"


# Allow replication HBA
sudo su -l postgres -c "echo \"host    replication     replicator      127.0.0.1/32            md5\" >> $MASTER_PGDATA/pg_hba.conf"

# Restart primary for changes to take effect (only archive_mode requires the restart)
sudo su -l postgres -c "/usr/pgsql-10/bin/pg_ctl -D $MASTER_PGDATA stop -m fast"
sudo su -l postgres -c "/usr/pgsql-10/bin/pg_ctl -D $MASTER_PGDATA start -w"

#
# Take backup of primary for replica base, into replica data directory
# (This can also be done from a remote host)
#
sudo su -l postgres -c "pg_basebackup -h localhost -D $REPLICA_PGDATA -P -U replicator --wal-method=stream"

#
# Change port on replica
#
sudo su -l postgres -c "sed -i 's/port = $MASTER_PGPORT/port = $REPLICA_PGPORT/g' $REPLICA_PGDATA/postgresql.conf"

#
# Configure recovery.conf
#
sudo su -l postgres -c "echo \"standby_mode     = 'on'\" >> $REPLICA_PGDATA/recovery.conf"
sudo su -l postgres -c "echo \"primary_conninfo = 'host=127.0.0.1 port=$MASTER_PGPORT user=replicator'\" >> $REPLICA_PGDATA/recovery.conf"
sudo su -l postgres -c "echo \"restore_command  = 'cp $WAL_ARCHIVE_DIRECTORY/%f "%p"'\" >> $REPLICA_PGDATA/recovery.conf"

#
# Start replica
#
sudo su -l postgres -c "/usr/pgsql-10/bin/pg_ctl -D $REPLICA_PGDATA start -w"
sleep 2

# Check status on primary
echo "Replication Statisticss from Primary:"
sudo su -l postgres -c "psql -c \"select pid, usename, client_addr, state, sent_lsn, replay_lsn from pg_stat_replication;\""

# Check status on standby
echo "Recovery Status from Replica:"
sudo su -l postgres -c "psql -p $REPLICA_PGPORT -c \"select pg_is_in_recovery();\""
