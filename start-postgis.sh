#!/bin/bash

# This script will run as the postgres user due to the Dockerfile USER directive

DATADIR="/var/lib/postgresql/13/data"
CONF="/var/lib/postgresql/13/data/postgresql.conf"
POSTGRES="/usr/lib/postgresql/13/bin/postgres"
INITDB="/usr/lib/postgresql/13/bin/initdb"
SQLDIR="/usr/share/postgresql/13/contrib/postgis-3.1/"
LOCALONLY="-c listen_addresses='127.0.0.1, ::1'"

# /etc/ssl/private can't be accessed from within container for some reason
# (@andrewgodwin says it's something AUFS related)  - taken from https://github.com/orchardup/docker-postgresql/blob/master/Dockerfile
cp -r /etc/ssl /tmp/ssl-copy/
chmod -R 0700 /etc/ssl
chown -R postgres /tmp/ssl-copy
rm -r /etc/ssl
mv /tmp/ssl-copy /etc/ssl

# test if DATADIR is existent
if [ ! -d $DATADIR ]; then
  echo "Creating Postgres data at $DATADIR"
  mkdir -p $DATADIR
fi
# needs to be done as root:
chown -R postgres:postgres $DATADIR

# Note that $POSTGRES_USER and $POSTGRES_PASS below are optional paramters that can be passed
# via docker run e.g.
#docker run --name="postgis" -e POSTGRES_USER=qgis -e POSTGRES_PASSWORD=qgis -d -v 
#/var/docker-data/postgres-dat:/var/lib/postgresql/data -t postgis/postgis:13-3.3

# If you dont specify a user/password in docker run, we will generate one
# here and create a user called 'docker' to go with it.


# test if DATADIR has content
if [ ! "$(ls -A $DATADIR)" ]; then

  # No content yet - first time pg is being run!
  # Initialise db
  echo "Initializing Postgres Database at $DATADIR"
  #chown -R postgres $DATADIR
  su - postgres -c "$INITDB $DATADIR"
fi

# Make sure we have a user set up
if [ -z "$POSTGRES_USER" ]; then
  POSTGRES_USER=docker
fi  
if [ -z "$POSTGRES_PASSWORD" ]; then
  POSTGRES_PASSWORD=docker
fi  
# Enable hstore and topology by default
if [ -z "$HSTORE" ]; then
  HSTORE=true
fi  
if [ -z "$TOPOLOGY" ]; then
  TOPOLOGY=true
fi  

# Custom IP range via docker run -e (https://docs.docker.com/engine/reference/run/#env-environment-variables)
# Usage is: docker run [...] -e ALLOW_IP_RANGE='192.168.0.0/16' 
if [ "$ALLOW_IP_RANGE" ]
then
  echo "host    all             all             $ALLOW_IP_RANGE              md5" >> /var/lib/postgresql/13/data/pg_hba.conf
fi

# redirect user/password into a file so we can echo it into
# docker logs when container starts
# so that we can tell user their password
echo "postgresql user: $POSTGRES_USER" > /tmp/PGPASSWORD.txt
echo "postgresql password: $POSTGRES_PASSWORD" >> /tmp/PGPASSWORD.txt
su - postgres -c "$POSTGRES --single -D $DATADIR -c config_file=$CONF <<< \"CREATE USER $POSTGRES_USER WITH SUPERUSER ENCRYPTED PASSWORD '$POSTGRES_PASSWORD';\""

su - postgres -c "$POSTGRES -D $DATADIR -c config_file=$CONF $LOCALONLY &"
sleep 1


# wait for postgres to come up
until `nc -z 127.0.0.1 5432`; do
    echo "$(date) - waiting for postgres (localhost-only)..."
    sleep 1
done
# echo "postgres ready"

RESULT=`su - postgres -c "psql -l | grep postgis | wc -l"`
if [[ ${RESULT} == '1' ]]
then
    echo 'Postgis Already There'

    if [[ ${HSTORE} == "true" ]]; then
        echo 'HSTORE is only useful when you create the postgis database.'
    fi
    if [[ ${TOPOLOGY} == "true" ]]; then
        echo 'TOPOLOGY is only useful when you create the postgis database.'
    fi
else
    echo "Postgis is missing, installing now"
    # Note the dockerfile must have put the postgis.sql and spatialrefsys.sql scripts into /root/
    # We use template0 since we want t different encoding to template1
    echo "Creating template postgis"
    su - postgres -c "createdb template_postgis -E UTF8 -T template0"
    echo "Enabling template_postgis as a template"
    CMD="UPDATE pg_database SET datistemplate = TRUE WHERE datname = 'template_postgis';"
    su - postgres -c "psql -c \"$CMD\""
    echo "Loading postgis extension"
    su - postgres -c "psql template_postgis -c 'CREATE EXTENSION postgis;'"

    if [[ ${HSTORE} == "true" ]]
    then
        echo "Enabling hstore in the template"
        su - postgres -c "psql template_postgis -c 'CREATE EXTENSION hstore;'"
    fi
    if [[ ${TOPOLOGY} == "true" ]]
    then
        echo "Enabling topology in the template"
        su - postgres -c "psql template_postgis -c 'CREATE EXTENSION postgis_topology;'"
    fi

    # Needed when importing old dumps using e.g ndims for constraints
    #echo "Loading legacy sql"
    #su - postgres -c "psql template_postgis -f $SQLDIR/legacy_minimal.sql"
    #su - postgres -c "psql template_postgis -f $SQLDIR/legacy_gist.sql"
    # Create a default db called 'gis' that you can use to get up and running quickly
    # It will be owned by the docker db user
    su - postgres -c "createdb -O $POSTGRES_USER -T template_postgis gis"
fi
# This should show up in docker logs afterwards
su - postgres -c "psql -l"

wait_postgres () {
    # Wait for background postgres main process to exit
    while [ "$(ls -A $DATADIR/postmaster.pid 2>/dev/null)" ]; do
        sleep 1
    done
}

stop_postgres () {
    if [ "$(ls -A $DATADIR/postmaster.pid 2>/dev/null)" ]; then
        kill -TERM `cat $DATADIR/postmaster.pid`
    fi
}

kill -TERM `cat $DATADIR/postmaster.pid`
wait_postgres
trap 'stop_postgres' TERM
echo "Postgres initialisation process completed .... restarting in foreground"
SETVARS="POSTGIS_ENABLE_OUTDB_RASTERS=1 POSTGIS_GDAL_ENABLED_DRIVERS=ENABLE_ALL"
su - postgres -c "$SETVARS $POSTGRES -D $DATADIR -c config_file=$CONF &"
sleep 3
wait_postgres
# su postgres -c "/usr/lib/postgresql/13/bin/pg_ctl -D /var/lib/postgresql/13/data -l logfile start"