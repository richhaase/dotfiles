#!/bin/sh

DB=dev_beatport_rhaase
HOST=bpdbdev002.co0
LOGHOST=bpdbdev002.co0
#DB=metrics

# PROD MASTERS

#HOST=bpdbmaster003.co1
#LOGHOST=bpdbmaster003.co1

#HOST=bpdbcartmaster003.co1
#LOGHOST=bpdbcartmaster003.co1

#HOST=bpdbmetricmaster001.co1
#LOGHOST=bpdbmetricmaster001.co1

#HOST=bpdbdw001.co1
#LOGHOST=bpdbdw001.co1

# PROD AUDITS

#HOST=bpdbaudit001.co1
#LOGHOST=bpdbaudit001.co1

#HOST=bpdbcartaudit001.co1
#LOGHOST=bpdbcartaudit001.co1

# STAGE MASTERS

#HOST=bpdbmasterstage003.co1
#LOGHOST=bpdbmasterstage003.co1

#HOST=bpdbcartmasterstage003.co1
#LOGHOST=bpdbcartmasterstage003.co1

#HOST=bpdbdwstage001.co1
#LOGHOST=bpdbdwstage001.co1

# STAGE AUDITS

#HOST=bpdbauditstage002.co1
#LOGHOST=bpdbauditstage002.co1

#HOST=bpdbcartauditstage001.co1
#LOGHOST=bpdbcartauditstage001.co1

function run_migration() {
    # $1 = Script to run
    mysql -u rhaase -v -v -t -p -h $HOST $DB < "$1" > "$1.$LOGHOST.$DB.log"
}

echo
echo "HOST:    $HOST"
echo "LOGHOST: $LOGHOST"
echo "DATABASE: " $DB
echo
echo "STATUS" | mysql -u rhaase -p -h $HOST $DB 

for file in $@; do
    echo running migration $file on $DB
    run_migration $file
done
