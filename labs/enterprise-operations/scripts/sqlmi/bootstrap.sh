#!/usr/bin/env bash
set -euo pipefail

: "${SQLMI_FQDN:?SQLMI_FQDN is required}"
: "${SQLMI_DATABASE:?SQLMI_DATABASE is required}"
: "${SQLMI_ACCESS_TOKEN:?SQLMI_ACCESS_TOKEN is required}"

export DEBIAN_FRONTEND=noninteractive

if ! python3 -c 'import pyodbc' >/dev/null 2>&1; then
  curl -sSL -O https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb
  dpkg -i packages-microsoft-prod.deb
  rm -f packages-microsoft-prod.deb
  apt-get update
  ACCEPT_EULA=Y apt-get install -y msodbcsql18 unixodbc python3-pyodbc
fi

install -d -m 0700 /etc/sre-sqlmi
install -d -m 0755 /opt/sre-sqlmi

python3 - <<'PY'
import os
import re
import struct

import pyodbc

token_bytes = os.environ["SQLMI_ACCESS_TOKEN"].encode("utf-16-le")
token_struct = struct.pack(f"<I{len(token_bytes)}s", len(token_bytes), token_bytes)
connection_string = (
  f"Driver={{ODBC Driver 18 for SQL Server}};"
  f"Server=tcp:{os.environ['SQLMI_FQDN']},1433;"
  f"Database={os.environ['SQLMI_DATABASE']};"
  "Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30"
)

with open("/tmp/bootstrap.sql", encoding="utf-8") as source:
  script = source.read()

variables = {
  "DatabaseName": os.environ["SQLMI_DATABASE"],
}
for name, value in variables.items():
  script = script.replace(f"$({name})", value)
script = re.sub(r"^\s*:setvar\s+.*$", "", script, flags=re.MULTILINE)
batches = re.split(r"^\s*GO\s*$", script, flags=re.MULTILINE | re.IGNORECASE)

with pyodbc.connect(connection_string, attrs_before={1256: token_struct}, autocommit=True) as connection:
  cursor = connection.cursor()
  for batch in batches:
    if batch.strip():
      cursor.execute(batch)
PY

cat > /etc/sre-sqlmi/connection.env <<EOF
SQLMI_FQDN='${SQLMI_FQDN}'
SQLMI_DATABASE='${SQLMI_DATABASE}'
EOF
chmod 0600 /etc/sre-sqlmi/connection.env

install -m 0755 /tmp/sre-sqlmi /usr/local/bin/sre-sqlmi
rm -f /tmp/bootstrap.sql /tmp/sre-sqlmi

/usr/local/bin/sre-sqlmi diagnose >/var/log/sre-sqlmi-bootstrap.json
chmod 0600 /var/log/sre-sqlmi-bootstrap.json
unset SQLMI_ACCESS_TOKEN
