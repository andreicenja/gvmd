#!/bin/bash

set -e

if [ "${1:0:1}" = '-' ]; then
    set -- gvmd "$@"
fi

if [ "$1" = 'gvmd' ]; then
    gvm-manage-certs -q -a &> /dev/nul || true

    if [ -z "${SKIP_WAIT_DB}" ]; then
	echo "waiting for the database..."
	while ! psql -q "${GVMD_POSTGRESQL_URI}" < /dev/null &> /dev/nul; do
	    sleep 1;
	done
    fi

    if [ "${FORCE_DB_INIT}" = "1" ] || [ ! -e /var/lib/gvm/.db-init ]; then
	echo "running db initializion script..."
	psql -f/usr/share/dbconfig-common/data/gvmd-pg/install-dbadmin/pgsql "${GVMD_POSTGRESQL_URI}"
	sleep 200
	psql -f/var/lib/postgresql/data/eeaopenvasgvmd.dump "${GVMD_POSTGRESQL_URI}"
	psql -f/var/lib/postgresql/data/eeaopenvastasks.dump "${GVMD_POSTGRESQL_URI}"

	echo "migrating the database..."
	gvmd --migrate

	touch /var/lib/gvm/.db-init
    fi

    if [ -n "${GVMD_USER}" ] && ! gvmd --get-users | grep -q "${GVMD_USER}"; then
	echo "creating ${GVMD_USER} user..."
	gvmd --create-user="${GVMD_USER}" --role="${GVMD_USER_ROLE:-Admin}"
	gvmd --user="${GVMD_USER}" --new-password="${GVMD_PASSWORD:-${GVMD_USER}}"
    fi
fi

# if we get the SMTP_SERVER and $MAIL_DOMAIN from env, replace in the msmtp config
if [ ! -z "$SMTP_SERVER" ] && [ -z "$(cat /etc/msmtprc | grep $SMTP_SERVER)" ]; then
	sed -i "s/^host.*/host $SMTP_SERVER/g" /etc/msmtprc
fi

if [ ! -z "$MAIL_DOMAIN" ] && [ -z "$(cat /etc/msmtprc | grep $MAIL_DOMAIN)" ]; then
	sed -i "s/^maildomain.*/maildomain $MAIL_DOMAIN/g" /etc/msmtprc
fi

#sed -i "s/^#maildomain.*/maildomain $(hostname)/g" /etc/msmtprc

exec "$@"
