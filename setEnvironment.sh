#!/bin/bash

# Stop at first command failure.
set -e

# The database user password
POSTGRES_USER=dev
# The LDAP admin user password
POSTGRES_PASSWORD=dev

# The Keycloak host, this must be accessible from inside a docker network and run under HTTPS
KEYCLOAK_HOST=$(ip route get 1 | awk '{gsub("^.*src ",""); print $1; exit}')
# The Keycloak admin user
KEYCLOAK_USER=admin
# The Keycloak admin password
KEYCLOAK_PASSWORD=admin

# The current mode we're in, it's either create or update
MODE=$1

POSITIONAL_ARGS=()
NO_CONFIRM=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -y|--yes)
      NO_CONFIRM=true
      shift
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}"

if [ "$MODE" = "create" ]; then
  if ! "$NO_CONFIRM"; then
    read -rp "This will remove the current .env file. Do you really want to continue (y/n)? "
  fi
elif [ "$MODE" = "update" ]; then
  if ! "$NO_CONFIRM"; then
    read -rp "This will update the current .env file with your local IP only. Do you want to continue (y/n)? "
  fi
else
  echo "Missing argument 'create' or 'update'"
  exit 1
fi

# Check if prompted to continue
if ! "$NO_CONFIRM" && [[ ! $REPLY =~ ^[Yy]$ ]]; then
  exit 1
fi

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
ENV_FILE=.env

if [ "$MODE" = "create" ]; then
  rm -rf $SCRIPT_DIR/$ENV_FILE

  echo "POSTGRES_USER=${POSTGRES_USER}" >> $SCRIPT_DIR/$ENV_FILE
  echo "POSTGRES_PASSWORD=${POSTGRES_PASSWORD}" >> $SCRIPT_DIR/$ENV_FILE

  echo "KEYCLOAK_HOST=${KEYCLOAK_HOST}" >> $SCRIPT_DIR/$ENV_FILE
  echo "KEYCLOAK_USER=${KEYCLOAK_USER}" >> $SCRIPT_DIR/$ENV_FILE
  echo "KEYCLOAK_PASSWORD=${KEYCLOAK_PASSWORD}" >> $SCRIPT_DIR/$ENV_FILE

  echo "Successfully wrote $SCRIPT_DIR/$ENV_FILE"
else
  sed -i -E "s/KEYCLOAK_HOST=(.+)/KEYCLOAK_HOST=${KEYCLOAK_HOST}/" .env

  echo "Successfully updated local IP in $SCRIPT_DIR/$ENV_FILE"
fi

printf "Updating the SSL certificate\n"

sed -i -E "s/IP.2    = (.+)/IP.2    = ${KEYCLOAK_HOST}/g" nginx/ssl/localhost.conf

openssl req \
  -config ./nginx/ssl/localhost.conf \
  -addext basicConstraints=critical,CA:TRUE,pathlen:1 \
  -batch \
  -x509 \
  -nodes \
  -days 3650 \
  -newkey rsa:2048 \
  -keyout ./nginx/ssl/private/localhost.key \
  -out ./nginx/ssl/private/localhost.crt

if keytool -list -alias DEV -keystore ./geoserver/keystore/cacerts -noprompt -storepass changeit > /dev/null 2>&1; then
  keytool -delete -alias DEV -keystore ./geoserver/keystore/cacerts -noprompt -storepass changeit
fi
keytool -import -file ./nginx/ssl/private/localhost.crt -alias DEV -keystore ./geoserver/keystore/cacerts -noprompt -storepass changeit
