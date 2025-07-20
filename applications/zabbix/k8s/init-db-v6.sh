#!/bin/bash
# Proper Zabbix 6.0 database initialization script

set -e

echo "Starting Zabbix 6.0 database initialization..."

# Wait for MySQL to be ready
echo "Waiting for MySQL to be ready..."
until mysql -h zabbix-mysql -u root -p"ZabbixRoot123!" -e "SELECT 1" > /dev/null 2>&1; do
    echo "MySQL is unavailable - sleeping"
    sleep 5
done

echo "MySQL is ready!"

# Create the database and user
echo "Creating database and user..."
mysql -h zabbix-mysql -u root -p"ZabbixRoot123!" << 'EOF'
CREATE DATABASE IF NOT EXISTS zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER IF NOT EXISTS 'zabbix'@'%' IDENTIFIED BY 'zabbix123!';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'%';
FLUSH PRIVILEGES;
EOF

# Check if database is already initialized
TABLE_COUNT=$(mysql -h zabbix-mysql -u zabbix -p"zabbix123!" -D zabbix -e "SHOW TABLES;" 2>/dev/null | wc -l)
echo "Found $TABLE_COUNT tables in database"

if [ "$TABLE_COUNT" -gt 10 ]; then
    echo "Database is already initialized"
    exit 0
fi

echo "Database is empty, initializing with Zabbix 6.0 schema..."

# Download and install Zabbix 6.0 schema
cd /tmp
wget -q https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix/zabbix-sql-scripts_6.0.40-1+ubuntu22.04_all.deb
ar x zabbix-sql-scripts_6.0.40-1+ubuntu22.04_all.deb
tar xf data.tar.xz

# Import the schema
if [ -f usr/share/zabbix-sql-scripts/mysql/server.sql.gz ]; then
    echo "Importing Zabbix 6.0 schema..."
    zcat usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -h zabbix-mysql -u zabbix -p"zabbix123!" zabbix
    echo "Schema imported successfully"
else
    echo "Schema file not found, creating basic schema..."
    # Use the Zabbix server container to create initial schema
    echo "Schema files not found - will let server container initialize"
    exit 1
fi

echo "Database initialization completed successfully!"
