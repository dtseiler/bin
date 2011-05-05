#!/bin/bash

DATESTAMP=`date +%Y%m%d`
SITESFILE=${HOME}/.drupalsites
# SITESFILE contents are in the following format:
# SITENAME:DBNAME:DBUSER:DBPASSWD
DRUPALDIR=/path/to/drupal
BACKUPDIR=${HOME}/backups/${DATESTAMP}

mkdir -p ${BACKUPDIR}

# Backup the drupal codebase
echo -n "Backing up ${DRUPALDIR} ... "
cd ${DRUPALDIR}/../
tar -cjpf ${BACKUPDIR}/drupal_${DATESTAMP}.tar.bz2 drupal
echo "Done."

cd ${BACKUPDIR}

# Backup MySQL Databases
cat $SITESFILE | while read line; do
        #echo $line
        line=(${line//:/ })
        echo -n "Backing up MySQL db ${line[1]} ... "
        DUMPFILE=${line[0]}_${DATESTAMP}.sql
        mysqldump -u ${line[2]} -p${line[3]} ${line[1]} > ${DUMPFILE}
        gzip ${DUMPFILE}
        echo "Done."
done

echo "Backup completed, all files are in ${BACKUPDIR}."
