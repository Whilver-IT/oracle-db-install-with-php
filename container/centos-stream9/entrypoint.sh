#!/bin/bash

# パスワードは内部変数にして環境変数からすぐ削除
PASSWD=${ORACLE_PASSWD}
unset ORACLE_PASSWD

# ORACLE関連の設定
ORACLE_BASE=/opt/oracle
ORADATA=${ORACLE_BASE}/oradata
export ORACLE_HOME=$(find ${ORACLE_BASE}/product -maxdepth 2 -type d | grep dbhome | head -n 1)

# sqlplusコマンドがパスに通ってなければ通す
sqlplus -V &>/dev/null
if [ $? -ne 0 ]; then
  export PATH=${ORACLE_HOME}/bin:$PATH
fi

# NLS_LANGが設定されてなければ、デフォルトはJapanese_Japan.AL32UTF8
if [ -z "${NLS_LANG}" ]; then
  export NLS_LANG=Japanese_Japan.AL32UTF8
fi

# タイムゾーンセット
if [ ! -z "${TZ}" ] && [ -e "/usr/share/zoneinfo/${TZ}" ]; then
  ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime
fi

# ORACLEの起動スクリプト取得
ORACLE_INIT_SCRIPT=$(find /etc/init.d/ -type f | grep -E "oracle-(free|xe)" | head -n 1)

# /opt/oracle/oradataが空なら削除する
rmdir "${ORADATA}" 2> /dev/null

# /opt/oracle/oradataが存在するかどうかで処理を分ける
if [ -e "${ORADATA}" ]; then
  # 存在していたので、Oracleのプロセスがあるかを確認
  ps aux | grep [_]pmon > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    # 起動プロセスがないのでORACLEを起動
    ${ORACLE_INIT_SCRIPT} start
  fi
else
  # /opt/oracle/oradataが存在しない場合は、パスワードの設定有無を確認
  if [ ! -z "${PASSWD}" ]; then

    # パスワードが設定されているので、Oracleのconfigureを行い、PDBとユーザを作成

    # データベース構築
    echo ${PASSWD} > /tmp/orapasswd
    echo ${PASSWD} >> /tmp/orapasswd
    # XE対策でCV_ASSUME_DISTIDを付与
    env CV_ASSUME_DISTID=xxx ${ORACLE_INIT_SCRIPT} configure < /tmp/orapasswd
    rm -f /tmp/orapasswd

    # Pluggable Database作成(TESTPDBで作成)
    PDB=TESTPDB
    DATA_BASEDIR=$(find ${ORACLE_BASE} -maxdepth 2 -type d | grep oradata | grep -E 'FREE|XE')

    # Pluggable Database用のフォルダ作成
    mkdir ${DATA_BASEDIR}/${PDB}
    chown oracle:oinstall ${DATA_BASEDIR}/${PDB}
    chmod 750 ${DATA_BASEDIR}/${PDB}

    # Pluggable Databaseとテーブルスペースを作成
    echo "CREATE PLUGGABLE DATABASE ${PDB} ADMIN USER ${PDB}ADM IDENTIFIED BY ${PASSWD}adm FILE_NAME_CONVERT = ('${DATA_BASEDIR}/pdbseed', '${DATA_BASEDIR}/${PDB}');" | sqlplus -s SYS/${PASSWD}@//localhost:1521 AS SYSDBA
    echo "ALTER PLUGGABLE DATABASE ${PDB} OPEN;" | sqlplus -s SYS/${PASSWD}@//localhost:1521 AS SYSDBA
    echo "ALTER PLUGGABLE DATABASE ${PDB} SAVE STATE;" | sqlplus -s SYS/${PASSWD}@//localhost:1521 AS SYSDBA
    echo "CREATE TABLESPACE tablespace_test DATAFILE '${DATA_BASEDIR}/${PDB}/tablespace_test.dbf' SIZE 100M AUTOEXTEND ON MAXSIZE UNLIMITED;" | sqlplus -s SYS/${PASSWD}@//localhost:1521/${PDB} AS SYSDBA
    echo "CREATE TEMPORARY TABLESPACE temporary_test TEMPFILE '${DATA_BASEDIR}/${PDB}/temporary_test.dbf' SIZE 100M AUTOEXTEND ON MAXSIZE UNLIMITED;" | sqlplus -s SYS/${PASSWD}@//localhost:1521/${PDB} AS SYSDBA

    # パスワード期限は無期限にしておく(リスクもあるが…)
    echo "ALTER PROFILE DEFAULT LIMIT PASSWORD_LIFE_TIME UNLIMITED;" | sqlplus -s SYS/${PASSWD}@//localhost:1521/${PDB} AS SYSDBA

    # ユーザ作成(ユーザはTESTとする)
    USER=TEST
    echo "CREATE USER ${USER} IDENTIFIED BY ${PASSWD} DEFAULT TABLESPACE tablespace_test TEMPORARY TABLESPACE temporary_test;" | sqlplus -s SYS/${PASSWD}@//localhost:1521/${PDB} AS SYSDBA
    echo "GRANT CONNECT TO ${USER};" | sqlplus -s SYS/${PASSWD}@//localhost:1521/${PDB} AS SYSDBA
    echo "GRANT RESOURCE TO ${USER};" | sqlplus -s SYS/${PASSWD}@//localhost:1521/${PDB} AS SYSDBA
    echo "GRANT DBA TO ${USER};" | sqlplus -s SYS/${PASSWD}@//localhost:1521/${PDB} AS SYSDBA

    # 接続確認(23cからFROM DUALはなくても動くけど)
    cat <<EOF | sqlplus -s ${USER}/${PASSWD}@//localhost:1521/${PDB}
      SET HEADING OFF;
      SELECT '${PDB} CONNECTED' FROM DUAL;
EOF

    # test.phpのPDO部分を置換
    sed -i "s/%db%/\$db = new PDO\('oci:dbname=\/\/localhost:1521\/TESTPDB', '${USER}', '${PASSWD}', \$options\);/g" /var/www/html/test.php
  else
    echo "Please Retry Below"
    echo "env ORACLE_PASSWD={password} entrypoint"
  fi
fi

# php-fpm
PHP_FPM_CONF=/etc/opt/remi/php84/php-fpm.d/www-env.conf
if [ ! -e ${PHP_FPM_CONF} ] || [ -z ${PHP_FPM_CONF} ]; then
  echo "[www]" > ${PHP_FPM_CONF}
  echo "env[ORACLE_HOME] = ${ORACLE_HOME}" >> ${PHP_FPM_CONF}
  echo "env[NLS_LANG] = ${NLS_LANG}" >> ${PHP_FPM_CONF}
fi
ps aux | grep [p]hp-fpm > /dev/null 2>&1
if [ $? -ne 0 ]; then
  /opt/remi/php84/root/sbin/php-fpm -y /etc/opt/remi/php84/php-fpm.conf &
fi

# httpd
ps aux | grep [h]ttpd > /dev/null 2>&1
if [ $? -ne 0 ]; then
  httpd -DFOREGROUND 2>/dev/null &
fi

# コンテナ起動時は対話モードにする
if [ $$ -eq 1 ]; then
  exec /bin/bash
fi
