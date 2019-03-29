#!/bin/bash

# Create database and database user with password

DB_NAME=$1

if [ $# -eq 0 ]
  then
    echo ""
    echo "No arguments supplied."
    echo ""
    echo "<dbname> client-name (used for db name and db username)"
    echo ""
    echo "Usage: ./create-db.sh <dbname>"
    echo "Example: ./build.sh client-clientname"
    echo ""
    exit 1
fi

CREATE_TEMPLATE="create-db.sql"
CREATE_SQL="tmp-create-db.sql"

# Create strong password
PASSWD=`openssl rand -hex 42`

# Create temporary SQL-file for creating new database and user
sed "s/client-asiakas/$DB_NAME/g;s/strongpassword/$PASSWD/g" $CREATE_TEMPLATE > $CREATE_SQL

# Create the db and user
sudo bash -c "mysql -uroot -p < $CREATE_SQL"

echo $PASSWD