
dropdb -U postgres ${DATABASE}
dropuser -U postgres ${USER}

#createuser -ARD -U admin ${USER} -h localhost -P
createuser -ARD -U postgres ${USER}
createdb -E koi8-r -U postgres -O ${USER} ${DATABASE}
psql -U ${USER} ${DATABASE} < ${ROOT}/doc/database.sql
