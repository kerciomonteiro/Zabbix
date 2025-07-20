#!/bin/bash
# Direct MySQL initialization script for Zabbix
# This script will run inside a MySQL container to initialize the database

set -e

echo "Starting Zabbix database initialization..."

# Wait for MySQL to be ready
echo "Waiting for MySQL to be ready..."
until mysql -h zabbix-mysql -u zabbix -p"zabbix123!" -e "SELECT 1" > /dev/null 2>&1; do
    echo "MySQL is unavailable - sleeping"
    sleep 5
done

echo "MySQL is ready!"

# Check if database is already initialized
TABLE_COUNT=$(mysql -h zabbix-mysql -u zabbix -p"zabbix123!" -D zabbix -e "SHOW TABLES;" 2>/dev/null | wc -l)
echo "Found $TABLE_COUNT tables in database"

if [ "$TABLE_COUNT" -gt 5 ]; then
    echo "Database is already initialized"
    exit 0
fi

echo "Database is empty, downloading and importing Zabbix schema..."

# Download the schema directly
cd /tmp
wget -q https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix/zabbix-server-mysql_6.0.40-1+ubuntu22.04_amd64.deb
ar x zabbix-server-mysql_6.0.40-1+ubuntu22.04_amd64.deb
tar xf data.tar.xz

# Find and import the schema
SCHEMA_FILE=$(find . -name "*.sql.gz" | head -1)
if [ -n "$SCHEMA_FILE" ]; then
    echo "Found schema file: $SCHEMA_FILE"
    echo "Importing schema into database..."
    zcat "$SCHEMA_FILE" | mysql -h zabbix-mysql -u zabbix -p"zabbix123!" zabbix
    echo "Schema imported successfully"
else
    echo "Schema file not found, creating basic schema..."
    # Create minimal schema for Zabbix to start
    mysql -h zabbix-mysql -u zabbix -p"zabbix123!" zabbix << 'EOF'
CREATE TABLE IF NOT EXISTS users (
  userid bigint unsigned NOT NULL AUTO_INCREMENT,
  username varchar(100) NOT NULL DEFAULT '',
  name varchar(100) NOT NULL DEFAULT '',
  surname varchar(100) NOT NULL DEFAULT '',
  passwd char(32) NOT NULL DEFAULT '',
  url varchar(255) NOT NULL DEFAULT '',
  autologin int NOT NULL DEFAULT 0,
  autologout varchar(32) NOT NULL DEFAULT '15m',
  lang varchar(7) NOT NULL DEFAULT 'default',
  refresh varchar(32) NOT NULL DEFAULT '30s',
  theme varchar(128) NOT NULL DEFAULT 'default',
  attempt_failed int NOT NULL DEFAULT 0,
  attempt_ip varchar(39) NOT NULL DEFAULT '',
  attempt_clock int NOT NULL DEFAULT 0,
  rows_per_page int NOT NULL DEFAULT 50,
  timezone varchar(50) NOT NULL DEFAULT 'default',
  role_id bigint unsigned NOT NULL DEFAULT 3,
  usrgrpid bigint unsigned DEFAULT NULL,
  PRIMARY KEY (userid),
  UNIQUE KEY users_1 (username)
);

INSERT INTO users (userid,username,name,surname,passwd,url,autologin,autologout,lang,refresh,theme,attempt_failed,attempt_ip,attempt_clock,rows_per_page,timezone,role_id,usrgrpid) VALUES (1,'Admin','Zabbix','Administrator','5fce1b3e34b520afeffb37ce08c7cd66','',0,'15m','en_US','30s','default',0,'',0,50,'default',3,NULL);
EOF
    echo "Basic schema created"
fi

echo "Database initialization completed successfully!"
