# Oracle AI Database 26 Freeをインストールして最低限使用するところまで

## 1. 参考サイト

[Oracle Database 26ai Freeの紹介](https://qiita.com/nakaie/items/30e1338614601c52a476)  
[3コマンドで Oracle Database 26ai Free の インストール](https://qiita.com/nisshii0/items/092a4c74730960b8f9e1)  
[Installation Guide For Linux](https://docs.oracle.com/en/database/oracle/oracle-database/26/xeinl/installing-oracle-database-free.html#GUID-728E4F0A-DBD1-43B1-9837-C6A460432733)

## 2. 前提条件

Oracle AI Database 26 Freeをインストールするのに、以下の環境とした  
<table>
<tr><th>OS</th><th>ディスク容量</th><th>メモリ容量</th></tr>
<tr><td>AlmaLinux9(KVM)</td><td>20GB</td><td>4GB</td></tr>
</table>

ホストはdebian12の環境で、kvmで以下のように作成  
今回はAlmaLinux9の最小構成にインストール
```
$ mkdir /home/xxx/ISO
$ curl -L https://repo.almalinux.org/almalinux/9.6/isos/x86_64/AlmaLinux-9.6-x86_64-boot.iso -o /home/xxx/ISO/AlmaLinux-9.6-x86_64-boot.iso
$ mkdir -p /home/xxx/kvm/oracle23cfree
$ cp -p /usr/share/OVMF/OVMF_VARS.fd /home/xxx/kvm/oracle23cfree
$ qemu-img create -f qcow2 /home/xxx/kvm/oracle23cfree/oracle23cfree.qcow2 20G
$ qemu-system-x86_64 \
    -enable-kvm \
    -m 4096 \
    -smp 4 \
    -drive file=/home/xxx/kvm/oracle23cfree/oracle23cfree.qcow2,format=qcow2 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd \
    -drive if=pflash,format=raw,file=/home/xxx/kvm/oracle23cfree/OVMF_VARS.fd \
    -cdrom file=/home/xxx/ISO/AlmaLinux-9.6-x86_64-boot.iso \
    -netdev user,id=net0,hostfwd=tcp::8080-:80,hostfwd=tcp::50022-:22 \
    -device virtio-net-pci,netdev=net0 \
    -device virtio-vga \
    -display sdl \
    -boot c \
    -cpu host &
```
AlmaLinux9インストール後、一旦シャットダウンして、上記の-cdrom行を除いたものを再実行  
KVMでやってますが、普通にVirtualBox等の仮想環境でも大丈夫かと

## 3. Oracle AI Database 26 Freeのインストール

### 3-1. パッケージのインストール

```
$ sudo dnf install \
    https://yum.oracle.com/repo/OracleLinux/OL9/appstream/x86_64/getPackage/oracle-ai-database-preinstall-26ai-1.0-1.el9.x86_64.rpm \
    https://download.oracle.com/otn-pub/otn_software/db-free/oracle-ai-database-free-26ai-23.26.0-1.el9.x86_64.rpm
```
最後の方で、
```
[INFO] Oracle home installed successfully and ready to be configured.
To configure Oracle AI Database Free, optionally modify the parameters in '/etc/sysconfig/oracle-free-26ai.conf' and then run '/etc/init.d/oracle-free-26ai configure' as root.
```
というのが出るので、/etc/sysconfig/oracle-free-26ai.confを編集して、/etc/init.d/oracle-free-26ai configureをrootで実行しろっていうメッセージなのでそうする  
今回はテストのため、/etc/sysconfig/oracle-free-26ai.confは編集せずに実行する

/etc/sysconfig/oracle-free-26ai.confの中身は以下
```
$ sudo cat /etc/sysconfig/oracle-free-26ai.conf
#This is a configuration file to setup the Oracle AI Database.
#It is used when running '/etc/init.d/oracle-free-26ai configure'.

# LISTENER PORT used Database listener, Leave empty for automatic port assignment
LISTENER_PORT=

# Character set of the database
CHARSET=AL32UTF8

# Database file directory
# If not specified, database files are stored under Oracle base/oradata
DBFILE_DEST=

# DB Domain name
DB_DOMAIN=

# Configure TDE
CONFIGURE_TDE=false

# Encrypt Tablespaces list, Leave empty for user tablespace alone or provide ALL for encrypting all tablespaces
# For specific tablespaces use SYSTEM:true,SYSAUX:false
ENCRYPT_TABLESPACES=

# SKIP Validations, memory, space
SKIP_VALIDATIONS=false
```

### 3-2. 初期スクリプトの実行
```
$ sudo /etc/init.d/oracle-free-26ai configure
Specify a password to be used for database accounts. Oracle recommends that the password entered should be at least 8 characters in length, contain at least 1 uppercase character, 1 lower case character and 1 digit [0-9]. Note that the same password will be used for SYS, SYSTEM and PDBADMIN accounts: [パスワードを入力]
Confirm the password: [パスワード(確認)を入力]
Configuring Oracle Listener.
Listener configuration succeeded.
Configuring Oracle AI Database FREE.
SYSユーザー・パスワードを入力してください:
*****
SYSTEMユーザー・パスワードを入力してください:
*****
PDBADMINユーザー・パスワードを入力してください:
*****
DB操作の準備
7%完了
データベース・ファイルのコピー中
29%完了
Oracleインスタンスの作成および起動中
30%完了
33%完了
36%完了
39%完了
43%完了
データベース作成の完了
47%完了
49%完了
50%完了
プラガブル・データベースの作成
54%完了
71%完了
構成後アクションの実行
93%完了
カスタム・スクリプトを実行中
100%完了
データベースの作成が完了しました。詳細は、次の場所にあるログ・ファイルを参照してください:
/opt/oracle/cfgtoollogs/dbca/FREE。
データベース情報:
グローバル・データベース名:FREE
システム識別子(SID):FREE
詳細はログ・ファイル"/opt/oracle/cfgtoollogs/dbca/FREE/FREE.log"を参照してください。

Connect to Oracle AI Database using one of the connect strings:
     Pluggable database: localhost.localdomain/FREEPDB1
     Multitenant container database: localhost.localdomain
```

### 3-3. システムの起動など

システムの起動などは以下でOK  
```
$ sudo systemctl enable|disable|start|stop|restart oracle-free-26ai
```

## 4. 接続

rootでsqlplusで接続できるようにする

### 4-1. .bash_profileの設定

接続を容易にするため、.bash_profileに以下を記述  
多分.bashrcでも問題ないと思うが、参考サイトでは.bash_profileとあったのでそうする
```
$ sudo -i
# cp -p .bash_profile .bash_profile.default
# vi .bash_profile
(以下を末尾に追加)
export ORACLE_HOME=/opt/oracle/product/26ai/dbhomeFree
export NLS_LANG=Japanese_Japan.AL32UTF8
export PATH=$ORACLE_HOME/bin:$PATH
```

### 4-2. 接続

rootユーザで以下を実行
```
# sqlplus SYS/{設定したパスワード}@//localhost:1521/FREE as sysdba

SQL*Plus: Release 23.26.0.0.0 - Production on 土 10月 25 16:28:15 2025
Version 23.26.0.0.0

Copyright (c) 1982, 2025, Oracle.  All rights reserved.



Oracle AI Database 26ai Free Release 23.26.0.0.0 - Develop, Learn, and Run for Free
Version 23.26.0.0.0
に接続されました。
SQL>
```

## 5. プラガブル・データベース(PLUGGABLE DATABASE)

### 5-1. はじめに

FREEではXE同様にFREEPDB1というデフォルトのプラガブル・データベースがあるので、それを利用する場合はこの項は読み飛ばしてください  
ここでは新規プラガブル・データベースを作成して、その上にユーザやテーブルを作成するようにします

### 5-2. 既存PDBとファイル位置の確認

以下実行して、PDB$SEEDとFREEPDB1のファイル位置を確認

```
# sqlplus SYS/{パスワード}@//localhost:1521 as sysdba

SQL*Plus: Release 23.26.0.0.0 - Production on 日 10月 26 16:05:26 2025
Version 23.26.0.0.0

Copyright (c) 1982, 2025, Oracle.  All rights reserved.



Oracle AI Database 26ai Free Release 23.26.0.0.0 - Develop, Learn, and Run for Free
Version 23.26.0.0.0
に接続されました。
SQL> show pdbs

    CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
         2 PDB$SEED                       READ ONLY  NO
         3 FREEPDB1                       READ WRITE NO
SQL>alter session set container=PDB$SEED;

セッションが変更されました。

SQL> select file_name from dba_data_files;

FILE_NAME
--------------------------------------------------------------------------------
/opt/oracle/oradata/FREE/pdbseed/undotbs01.dbf
/opt/oracle/oradata/FREE/pdbseed/system01.dbf
/opt/oracle/oradata/FREE/pdbseed/sysaux01.dbf

SQL> alter session set container=FREEPDB1;

セッションが変更されました。

SQL> select file_name from dba_data_files;

FILE_NAME
--------------------------------------------------------------------------------
/opt/oracle/oradata/FREE/FREEPDB1/sysaux01.dbf
/opt/oracle/oradata/FREE/FREEPDB1/users01.dbf
/opt/oracle/oradata/FREE/FREEPDB1/system01.dbf
/opt/oracle/oradata/FREE/FREEPDB1/undotbs01.dbf

SQL>
```
PDB$SEEDは/opt/oracle/oradata/FREE/pdbseedディレクトリ  
FREEPDB1は/opt/oracle/oradata/FREE/FREEDB1ディレクトリ  
にファイルが有るので、今回はTESTPDBというPDBを/opt/oracle/oradata/FREE/TESTPDBに作ることにする  
(各自の環境で「FREEPDB」の部分は好きなものに置き換えていただいても構いません。また、DB名とディレクトリ名を合わせる必要もない(はず)です)

### 5-3. TESTPDBの作成

#### 5-3-1. /opt/oracle/oradata/FREE配下の確認

```
# ls -l /opt/oracle/oradata/FREE
合計 2432172
drwxr-x---. 2 oracle oinstall        104 10月 25 15:32 FREEPDB1
-rw-r-----. 1 oracle oinstall   18759680 10月 26 16:42 control01.ctl
-rw-r-----. 1 oracle oinstall   18759680 10月 26 16:42 control02.ctl
drwxr-x---. 2 oracle oinstall         85 10月 25 15:24 pdbseed
-rw-r-----. 1 oracle oinstall  209715712 10月 26 16:42 redo01.log
-rw-r-----. 1 oracle oinstall  209715712 10月 26 15:56 redo02.log
-rw-r-----. 1 oracle oinstall  209715712 10月 26 15:56 redo03.log
-rw-r-----. 1 oracle oinstall  681582592 10月 26 16:42 sysaux01.dbf
-rw-r-----. 1 oracle oinstall 1101012992 10月 26 16:31 system01.dbf
-rw-r-----. 1 oracle oinstall   20979712 10月 26 11:47 temp01.dbf
-rw-r-----. 1 oracle oinstall   31465472 10月 26 16:42 undotbs01.dbf
-rw-r-----. 1 oracle oinstall    7348224 10月 26 15:56 users01.dbf
```

#### 5-3-2. /opt/oracle/oradata/FREEにディレクトリTESTPDBを作成

```
# mkdir /opt/oracle/oradata/FREE/TESTPDB
# chown oracle:oinstall /opt/oracle/oradata/FREE/TESTPDB
# chmod 750 /opt/oracle/oradata/FREE/TESTPDB
# ls -l /opt/oracle/oradata/FREE
合計 2432172
drwxr-x---. 2 oracle oinstall        104 10月 25 15:32 FREEPDB1
drwxr-x---. 2 oracle oinstall          6 10月 26 17:16 TESTPDB
-rw-r-----. 1 oracle oinstall   18759680 10月 26 17:17 control01.ctl
-rw-r-----. 1 oracle oinstall   18759680 10月 26 17:17 control02.ctl
drwxr-x---. 2 oracle oinstall         85 10月 25 15:24 pdbseed
-rw-r-----. 1 oracle oinstall  209715712 10月 26 17:17 redo01.log
-rw-r-----. 1 oracle oinstall  209715712 10月 26 15:56 redo02.log
-rw-r-----. 1 oracle oinstall  209715712 10月 26 15:56 redo03.log
-rw-r-----. 1 oracle oinstall  681582592 10月 26 17:16 sysaux01.dbf
-rw-r-----. 1 oracle oinstall 1101012992 10月 26 17:16 system01.dbf
-rw-r-----. 1 oracle oinstall   20979712 10月 26 11:47 temp01.dbf
-rw-r-----. 1 oracle oinstall   31465472 10月 26 17:16 undotbs01.dbf
-rw-r-----. 1 oracle oinstall    7348224 10月 26 15:56 users01.dbf
```

#### 5-3-3. TESTPDBの作成

SQL*PlusでSYSでログインして、TESTPDBというプラガブル・データベースを作成
ADMIN USERはTESTPDBADMINとする

```
# sqlplus SYS/{パスワード}@//localhost:1521 as sysdba

SQL*Plus: Release 23.26.0.0.0 - Production on 日 10月 26 17:36:34 2025
Version 23.26.0.0.0

Copyright (c) 1982, 2025, Oracle.  All rights reserved.



Oracle AI Database 26ai Free Release 23.26.0.0.0 - Develop, Learn, and Run for Free
Version 23.26.0.0.0
に接続されました。
SQL> CREATE PLUGGABLE DATABASE TESTPDB ADMIN USER TESTPDBADMIN IDENTIFIED BY {パスワード} FILE_NAME_CONVERT = ('/opt/oracle/oradata/FREE/pdbseed', '/opt/oracle/oradata/FREE/TESTPDB');

プラガブル・データベースが作成されました。

SQL>
```
作成直後はMOUNTEDなので、openしてstateを保存したらログアウトする  
(以降、上記の続き)

```
SQL> show pdbs;

    CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
         2 PDB$SEED                       READ ONLY  NO
         3 FREEPDB1                       READ WRITE NO
         4 TESTPDB                        MOUNTED
SQL> ALTER PLUGGABLE DATABASE TESTPDB OPEN;

プラガブル・データベースが変更されました。

SQL> show pdbs;

    CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
         2 PDB$SEED                       READ ONLY  NO
         3 FREEPDB1                       READ WRITE NO
         4 TESTPDB                        READ WRITE NO
SQL> ALTER PLUGGABLE DATABASE TESTPDB SAVE STATE;

プラガブル・データベースが変更されました。

SQL> exit
Oracle AI Database 26ai Free Release 23.26.0.0.0 - Develop, Learn, and Run for Free
Version 23.26.0.0.0との接続が切断されました。
```
一旦ログアウトして、作成したプラガブル・データベースへADMIN USERでログインし、  
接続が確認できたらログアウト

```
# sqlplus TESTPDBADMIN/{パスワード}@//localhost:1521/TESTPDB

SQL*Plus: Release 23.26.0.0.0 - Production on 日 10月 26 17:45:05 2025
Version 23.26.0.0.0

Copyright (c) 1982, 2025, Oracle.  All rights reserved.



Oracle AI Database 26ai Free Release 23.26.0.0.0 - Develop, Learn, and Run for Free
Version 23.26.0.0.0
に接続されました。
SQL> exit
Oracle AI Database 26ai Free Release 23.26.0.0.0 - Develop, Learn, and Run for Free
Version 23.26.0.0.0との接続が切断されました。
```
作成されたファイルを確認してみる

```
# ls -l /opt/oracle/oradata/FREE/TESTPDB
合計 809040
-rw-r-----. 1 oracle oinstall 419438592 10月 26 17:47 sysaux01.dbf
-rw-r-----. 1 oracle oinstall 304095232 10月 26 17:47 system01.dbf
-rw-r-----. 1 oracle oinstall  20979712 10月 26 17:38 temp01.dbf
-rw-r-----. 1 oracle oinstall 104865792 10月 26 17:47 undotbs01.dbf
```

### 5-4. ユーザとテーブルの作成

#### 5-4-1. 既存PDBのTABLESPACEの確認

デフォルトのFREEPDB1のTABLESPACEの場所を確認

```
# sqlplus SYS/{パスワード}@//localhost:1521/FREEPDB1 as sysdba

SQL*Plus: Release 23.26.0.0.0 - Production on 日 10月 26 17:51:42 2025
Version 23.26.0.0.0

Copyright (c) 1982, 2025, Oracle.  All rights reserved.



Oracle AI Database 26ai Free Release 23.26.0.0.0 - Develop, Learn, and Run for Free
Version 23.26.0.0.0
に接続されました。
SQL> select file_name, tablespace_name from dba_data_files;

FILE_NAME
--------------------------------------------------------------------------------
TABLESPACE_NAME
------------------------------
/opt/oracle/oradata/FREE/FREEPDB1/sysaux01.dbf
SYSAUX

/opt/oracle/oradata/FREE/FREEPDB1/users01.dbf
USERS

/opt/oracle/oradata/FREE/FREEPDB1/system01.dbf
SYSTEM


FILE_NAME
--------------------------------------------------------------------------------
TABLESPACE_NAME
------------------------------
/opt/oracle/oradata/FREE/FREEPDB1/undotbs01.dbf
UNDOTBS1


SQL>
```
PDBのファイルと同じ場所に作られてるようなので、これと同じ要領で作成することにする

#### 5-4-2. TABLESPACE、TEMPORARY TABLESPACEの作成
以下の条件で、TABLESPACEとTEMPORARY TABLESPACEを作成する

<table>
<tr><th></th><th>ファイル名</th><th>拡張方法</th><th>制限</th></tr>
<tr><td>TABLESPACE</td><td>/opt/oracle/oradata/FREE/TESTPDB/tablespacetest.dbf</td><td>自動拡張100MB</td><td>無制限</td></tr>
<tr><td>TEMPORARY TABLESPACE</td><td>/opt/oracle/oradata/FREE/TESTPDB/temporarytest.dbf</td><td>自動拡張100MB</td><td>無制限</td></tr>
</table>
SYSユーザでAS sysdbaで対象のプラガブル・データベースに接続して実行(今回はTESTPDB)

```
# sqlplus SYS/{パスワード}@//localhost:1521/TESTPDB as sysdba

SQL*Plus: Release 23.26.0.0.0 - Production on 日 10月 26 17:59:01 2025
Version 23.26.0.0.0

Copyright (c) 1982, 2025, Oracle.  All rights reserved.



Oracle AI Database 26ai Free Release 23.26.0.0.0 - Develop, Learn, and Run for Free
Version 23.26.0.0.0
に接続されました。
SQL> CREATE TABLESPACE tablespacetest DATAFILE '/opt/oracle/oradata/FREE/TESTPDB/tablespacetest.dbf' SIZE 100M AUTOEXTEND ON MAXSIZE UNLIMITED;

表領域が作成されました。

SQL> CREATE TEMPORARY TABLESPACE temporarytest TEMPFILE '/opt/oracle/oradata/FREE/TESTPDB/temporarytest.dbf' SIZE 100M AUTOEXTEND ON MAXSIZE UNLIMITED;

表領域が作成されました。

SQL>
```

#### 5-4-3. USERの作成

ADMIN USERとは別にテーブル作成、データ作成の可能なユーザを作成する  
このユーザを実際には使用することにする  
ユーザの権限は以下GRANTの通りとしておく  

Oracleはユーザ作成後、デフォルトでは180日のパスワード有効期限なので、セキュリティ的にはよろしくないが無期限にしたい場合は、ALTER PROFILEで無期限にセットする  
(ここでは無期限としておく)

```
# sqlplus SYS/{パスワード}@//localhost:1521/TESTPDB as sysdba

SQL*Plus: Release 23.26.0.0.0 - Production on 日 10月 26 18:09:32 2025
Version 23.26.0.0.0

Copyright (c) 1982, 2025, Oracle.  All rights reserved.



Oracle AI Database 26ai Free Release 23.26.0.0.0 - Develop, Learn, and Run for Free
Version 23.26.0.0.0
に接続されました。
SQL> ALTER PROFILE DEFAULT LIMIT PASSWORD_LIFE_TIME UNLIMITED;

プロファイルが変更されました。

SQL> CREATE USER {ユーザ} IDENTIFIED BY {パスワード} DEFAULT TABLESPACE tablespacetest TEMPORARY TABLESPACE temporarytest;

ユーザーが作成されました。

SQL> GRANT CONNECT TO {ユーザ};

権限付与が成功しました。

SQL> GRANT RESOURCE TO {ユーザ};

権限付与が成功しました。

SQL> GRANT DBA TO {ユーザ};

権限付与が成功しました。

SQL>
```

#### 5-4-4. テーブルの作成

5-4-3で作成したユーザで作成したプラガブル・データベースにアクセスして、テーブルの作成、データの作成等を行う

```
# sqlplus {ユーザ}/{パスワード}@//localhost:1521/TESTPDB

SQL*Plus: Release 23.26.0.0.0 - Production on 日 10月 26 18:15:29 2025
Version 23.26.0.0.0

Copyright (c) 1982, 2025, Oracle.  All rights reserved.



Oracle AI Database 26ai Free Release 23.26.0.0.0 - Develop, Learn, and Run for Free
Version 23.26.0.0.0
に接続されました。
SQL> CREATE TABLE TEST (id VARCHAR2(16) NOT NULL PRIMARY KEY, name CLOB);

表が作成されました。

SQL> INSERT INTO TEST (id, name) VALUES ('shirogane', '白銀');

1行が作成されました。

SQL> select * from TEST;

ID
----------------
NAME
--------------------------------------------------------------------------------
shirogane
白銀


SQL> UPDATE TEST SET name = 'オラクル' WHERE id = 'shirogane';

1行が更新されました。

SQL> select * from TEST;

ID
----------------
NAME
--------------------------------------------------------------------------------
shirogane
オラクル


SQL> DELETE FROM TEST WHERE id = 'shirogane';

1行が削除されました。

SQL> select count(*) from TEST;

  COUNT(*)
----------
         0

SQL> DROP TABLE TEST;

表が削除されました。

SQL> exit
Oracle AI Database 26ai Free Release 23.26.0.0.0 - Develop, Learn, and Run for Free
Version 23.26.0.0.0との接続が切断されました。
```

## 6. tnsnames.ora

$ORACLE_HOME/network/admin/tnsnames.ora  
に接続文字列を定義しておけば、その接続文字列だけで接続させることが可能になります  
もしファイルが存在しなければ作成し、ファイルが既に存在し定義が既にある場合は追記してください  
例えば、上記の  
`# sqlplus {ユーザ}/{パスワード}@//localhost:1521/TESTPDB`  
を  
`# sqlplus {ユーザ}/{パスワード}@TNS_FREE`  
で接続するなら以下のように設定すればよいです
```
# 表記の定義
{接続文字列} =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = {HOST名 or IPアドレス})(PORT = {ポート番号}))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = {DB名})
    )
  )

# 以下のように定義することで、接続文字列「TNS_FREE」だけで接続が可能
TNS_FREE =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = TESTPDB)
    )
  )
```

以下、実際のコマンド
```
# sqlplus {ユーザ名}/{パスワード}@TNS_FREE

SQL*Plus: Release 23.26.0.0.0 - Production on 日 11月 30 15:51:10 2025
Version 23.26.0.0.0

Copyright (c) 1982, 2025, Oracle.  All rights reserved.

最終正常ログイン時間: 日 11月 30 2025 15:38:23 +09:00


Oracle AI Database 26ai Free Release 23.26.0.0.0 - Develop, Learn, and Run for Free
Version 23.26.0.0.0
に接続されました。
SQL> 
```

ここまでできれば完了です。お疲れ様でした。
