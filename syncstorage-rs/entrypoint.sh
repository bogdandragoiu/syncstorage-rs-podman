#!/bin/bash
# set -x 

sleep 5

/usr/local/cargo/bin/diesel --database-url "mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@${MYSQL_HOSTNAME}:${MYSQL_PORT}/syncstorage_rs" migration --migration-dir syncstorage-mysql/migrations run
/usr/local/cargo/bin/diesel --database-url "mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@${MYSQL_HOSTNAME}:${MYSQL_PORT}/tokenserver_rs" migration --migration-dir tokenserver-db/migrations run


proto="$(echo mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@${MYSQL_HOSTNAME}:${MYSQL_PORT}/tokenserver_rs | grep :// | sed -e's,^\(.*://\).*,\1,g')"
url="$(echo mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@${MYSQL_HOSTNAME}:${MYSQL_PORT}/tokenserver_rs/$proto/})"
userpass="$(echo $url | grep @ | cut -d@ -f1)"
pass="${MYSQL_PASSWORD}"
user="${MYSQL_USER}"
host="${MYSQL_HOSTNAME}"
port="${MYSQL_PORT}"
db="tokenserver_rs"

# Create service and node if they doesnt exist
mysql $db -h $host -P $port -u $user -p"$pass" <<EOF
DELETE FROM services;
INSERT INTO services (id, service, pattern) VALUES
    (1, "sync-1.5", "{node}/1.5/{uid}");
INSERT INTO nodes (id, service, node, capacity, available, current_load, downed, backoff) VALUES
    (1, 1, "${SYNC_URL}", ${SYNC_CAPACITY}, ${SYNC_CAPACITY}, 0, 0, 0)
    ON DUPLICATE KEY UPDATE node = "${SYNC_URL}", capacity = ${SYNC_CAPACITY}, available = (SELECT ${SYNC_CAPACITY} - current_load from (SELECT * FROM nodes) as n2 where id = 1);
EOF

# Write config file
cat > /config/local.toml <<EOF
master_secret = "${SYNC_MASTER_SECRET}"

human_logs = 1

host = "0.0.0.0"
port = 8000

syncstorage.database_url = "mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@${MYSQL_HOSTNAME}:${MYSQL_PORT}/syncstorage_rs"
syncstorage.enable_quota = 0
syncstorage.enabled = true

tokenserver.database_url = "mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@${MYSQL_HOSTNAME}:${MYSQL_PORT}/tokenserver_rs"
tokenserver.enabled = true
tokenserver.fxa_email_domain = "api.accounts.firefox.com"
tokenserver.fxa_metrics_hash_secret = "${METRICS_HASH_SECRET}"
tokenserver.fxa_oauth_server_url = "https://oauth.accounts.firefox.com"
tokenserver.fxa_browserid_audience = "https://token.services.mozilla.com"
tokenserver.fxa_browserid_issuer = "https://api.accounts.firefox.com"
tokenserver.fxa_browserid_server_url = "https://verifier.accounts.firefox.com/v2"
EOF

# Enter venv and run server
if [ -z "$LOGLEVEL" ]; then
  LOGLEVEL=warn
fi

source /app/venv/bin/activate
RUST_LOG=$LOGLEVEL /usr/local/cargo/bin/syncserver --config /config/local.toml
