# PHPからPDO-OCIを使用して、Oracle Database Free 26aiに接続するところまで

## 1. 目的

Oracle AI Database 26 Freeはインストール済  
(インストール方法は[oracle-database-free.md](oracle-database-free.md)を参照ください)  
このマシンと同じマシン内から、PHPからOracleにアクセスすることを目的とする  
検証のため、SELinuxとfirewalldは無効にしておきます  
今回は、Remiリポジトリからインストールし、phpのバージョンは8.4とします

## 2. Remiリポジトリのインストール

PHPはRemiリポジトリから入れる  
```
$ sudo dnf install https://rpms.remirepo.net/enterprise/remi-release-9.rpm
```

## 3. OCI8とPDO_OCIモジュールのインストール

OCI8とPDO_OCIのインストールには以下の2つの方法で可能

1. peclでインストール  
メリット： 正攻法で、迷わなくてよい  
デメリット： gcc等でコンパイルするためのパッケージを余計に入れないといけない

2. dnfでphp84-php-pecl-oci8、php84-php-pecl-pdo_ociパッケージをインストール  
メリット： gcc等のコンパイルパッケージが不要  
デメリット： rpmbuild用のパッケージが必要なのと、remiの要求するlibclntsh.soのバージョンとOracleのlibclntsh.soのバージョンが一致していることが条件

後者の条件であれば、一旦rpmさえ作っておけば使い回しがきくので、そうなればrpmbuild用のパッケージも不要

### 3-1. peclでインストール

#### 3-1-1. 必要なパッケージのインストール

この時点でmakeは入っていると思うけど…

```
$ sudo dnf install php84-php-devel php84-php-pear php84-php-pdo gcc make autoconf
```

#### 3-1-2. oci8のインストール

```
$ sudo /opt/remi/php84/root/bin/pecl install oci8
```
以下メッセージが出たら、/opt/oracle/product/26ai/dbhomeFree
と入力する
```
Please provide the path to the ORACLE_HOME directory. Use 'instantclient,/path/to/instant/client/lib' if you're compiling with Oracle Instant Client [autodetect] : /opt/oracle/product/26ai/dbhomeFree
```
うまくいけば、下記メッセージが表示される
```
Build process completed successfully
Installing '/opt/remi/php84/root/usr/lib64/php/modules/oci8.so'
install ok: channel://pecl.php.net/oci8-3.4.0
configuration option "php_ini" is not set to php.ini location
You should add "extension=oci8.so" to php.ini
```
なので、以下のようにoci8が有効になるように、iniに追加して、有効になったか確認
```
$ echo extension=oci8.so | sudo tee /etc/opt/remi/php84/php.d/20-oci8.ini
$ php84 -i | grep -i oci
/etc/opt/remi/php84/php.d/20-oci8.ini,
oci8
OCI8 Support => enabled
OCI8 DTrace Support => disabled
OCI8 Version => 3.4.0
oci8.connection_class => no value => no value
oci8.default_prefetch => 100 => 100
oci8.events => Off => Off
oci8.max_persistent => -1 => -1
oci8.old_oci_close_semantics => Off => Off
oci8.persistent_timeout => -1 => -1
oci8.ping_interval => 60 => 60
oci8.prefetch_lob_size => 0 => 0
oci8.privileged_connect => Off => Off
oci8.statement_cache_size => 20 => 20
```
oci8が有効になっていればOK

#### 3-1-3. PDO_OCIのインストール

oci8の時と同様、以下

```
$ sudo /opt/remi/php84/root/bin/pecl install pdo_oci
```
同様に、以下聞かれるので同上
```
Please provide the path to the ORACLE_HOME directory. Use 'instantclient,/path/to/instant/client/lib' if you're compiling with Oracle Instant Client [autodetect] : /opt/oracle/product/26ai/dbhomeFree
```
うまくいけば、下記メッセージが表示される
```
Build process completed successfully
Installing '/opt/remi/php84/root/usr/lib64/php/modules/pdo_oci.so'
install ok: channel://pecl.php.net/pdo_oci-1.1.0
configuration option "php_ini" is not set to php.ini location
You should add "extension=pdo_oci.so" to php.ini
```
同様にiniに追加して、有効になったか確認
```
# echo extension=pdo_oci.so > /etc/opt/remi/php84/php.d/40-pdo_oci.ini
# php84 -i | grep -i pdo
/etc/opt/remi/php84/php.d/20-pdo.ini,
/etc/opt/remi/php84/php.d/30-pdo_sqlite.ini,
/etc/opt/remi/php84/php.d/40-pdo_oci.ini,
PDO
PDO support => enabled
PDO drivers => oci, sqlite
PDO_OCI
PDO Driver for OCI 8 and later => enabled
PDO_OCI extension version => 1.1.0
pdo_sqlite
PDO Driver for SQLite 3.x => enabled
```
pdo_ociの項目が現れたらOK  
ここまでできたら、4へ

### 3-2. dnfでphp84-php-pecl-oci8、php84-php-pdo_ociをインストール

#### 3-2-1. インストールの前に

Remiリポジトリのphp8.4では、php84-php-pecl-oci8とphp84-php-pdo_ociパッケージが用意されています  
しかし、Oracle InstantClientのrpmには、libclntsh.so.xx.1()(64bit)の依存が含まれていますが、Oracleのrpmではこの依存を解消することができないため、そのままインストールしようとしても失敗します  
しかし、  
/opt/oracle/product/26ai/dbhomeFree/lib  
には、libclntsh.so.xxは含まれているので、この依存を満たすRPMを作成することでインストールできるようにします

普通にインストールしようとしても失敗
```
$ sudo dnf install php84-php-pecl-oci8
メタデータの期限切れの最終確認: 0:04:50 前の 2025年11月19日 14時31分06秒 に実施しました。
エラー:
 問題: ジョブの最良アップデート候補をインストールできません
  - nothing provides libclntsh.so.23.1()(64bit) needed by php84-php-pecl-oci8-3.4.0-3.el9.remi.x86_64 from remi-safe
(インストール不可のパッケージをスキップするには、'--skip-broken' を追加してみてください または、'--nobest' を追加して、最適候補のパッケージのみを使用しないでください)
```
でも、ライブラリ自体はORACLE_HOME(/opt/oracle/product/26ai/dbhomeFree)/libにある
```
$ ls /opt/oracle/product/26ai/dbhomeFree/lib | grep libclntsh\.so
libclntsh.so
libclntsh.so.10.1
libclntsh.so.11.1
libclntsh.so.12.1
libclntsh.so.18.1
libclntsh.so.19.1
libclntsh.so.20.1
libclntsh.so.21.1
libclntsh.so.22.1
libclntsh.so.23.1
libclntsh.so.23.1.comment.gz
```

#### 3-2-2. Shared Libraryへの追加

libclntsh.soをShared Libraryへ追加する

```
$ echo /opt/oracle/product/26ai/dbhomeFree/lib | sudo tee /etc/ld.so.conf.d/oracle.conf
$ sudo ldconfig
```

#### 3-2-3. 依存解消パッケージの作成

ここは、RHEL系の別環境で作成しても大丈夫です  
そうやって、できあがったrpmだけ持ってくれば、Oracleのインストールされたサーバを汚さずに済みます  

まずは、rpmdevtoolsのインストールし、rpmdev-setuptreeを実行
```
$ sudo dnf install rpmdevtools
$ rpmdev-setuptree
$ tree  ~/rpmbuild
/home/gari/rpmbuild
├── BUILD
├── RPMS
├── SOURCES
├── SPECS
└── SRPMS
```
これで、~/rpmbuild配下で、独自rpmを作成する環境が生成される

~/rpmbuild/SPECS  
配下に、以下のようなSPECファイルを作成

```
$ cat ~/rpmbuild/SPEC/libclntsh-fake-package-23.1-1.el9.whilver.noarch.spec
Name: libclntsh-fake-package
Version: 23.1
Release: 1.el9.whilver
Summary: Fake package to provide libclntsh.so.23.1 dependancy
License: Public Domain
BuildArch: noarch
Provides: libclntsh.so.23.1()(64bit)
Provides: libclntsh.so.23()(64bit)
Provides: libclntsh
%description
Fake package prividing the libclntsh.so.23.1 dependancy
Contains no files
%prep
%build
%install
%files
```
作成したらbuild
```
$ rpmbuild -ba ~/rpmbuild/SPEC/libclntsh-fake-package-23.1-1.el9.whilver.noarch.spec
```

#### 3-2-4. php84-php-pecl-oci8、php84-php-pdo_ociのインストール

3-2-2で作成したrpmと一緒にdnfコマンドでインストールするだけ  
(次でcliで実行するため、ここでphp84-phpを入れておく)
```
$ sudo dnf install php84-php php84-php-oci8 php84-php-pdo_oci rpmbuild/RPMS/noarch/oracle-libclntsh-fake.noarch.rpm
```
インストール後、モジュールが呼ばれているか確認
```
$ php84 -i | grep -iE 'oci|pdo'
/etc/opt/remi/php84/php.d/20-pdo.ini,
/etc/opt/remi/php84/php.d/30-pdo_sqlite.ini,
/etc/opt/remi/php84/php.d/40-oci8.ini,
/etc/opt/remi/php84/php.d/40-pdo_oci.ini
oci8
OCI8 Support => enabled
OCI8 DTrace Support => enabled
OCI8 Version => 3.4.0
oci8.connection_class => no value => no value
oci8.default_prefetch => 100 => 100
oci8.events => Off => Off
oci8.max_persistent => -1 => -1
oci8.old_oci_close_semantics => Off => Off
oci8.persistent_timeout => -1 => -1
oci8.ping_interval => 60 => 60
oci8.prefetch_lob_size => 0 => 0
oci8.privileged_connect => Off => Off
oci8.statement_cache_size => 20 => 20
PDO
PDO support => enabled
PDO drivers => sqlite, oci
PDO_OCI
PDO Driver for OCI 8 and later => enabled
PDO_OCI extension version => 1.1.0
pdo_sqlite
PDO Driver for SQLite 3.x => enabled
```

## 4. PHPからPDO経由でOracle AI Database 26 FREEに接続できるか確認

### 4-1. 必要なパッケージをインストール

oci8とpdo_ociを入れるのに最低限のパッケージしか入れていなかったので、必要なものをインストール  
一旦、mbstringだけ入れておく  
(3-2の場合は既に入っているかも)

```
$ sudo dnf install php84-php-mbstring
```

### 4-2. 検証スクリプトを書いて確認

```php
<?php
date_default_timezone_set('Asia/Tokyo');
mb_internal_encoding('UTF-8');

// PDO接続
$options = [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
];
// tnsnames.oraの設定(例:TNS_TESTPDB)を利用する場合は以下コメントのようになる
//$db = new PDO('oci:dbname=TNS_TESTPDB', '{ユーザ}', '{パスワード}', $options);
$db = new PDO('oci:dbname=//localhost:1521/TESTPDB', '{ユーザ}', '{パスワード}', $options);

// TABLEが既に作成されているかもしれないことを考慮して、存在していたらDROPする
$stmt = $db->prepare('SELECT COUNT(*) AS CNT FROM USER_TABLES WHERE TABLE_NAME = :table_name');
$stmt->bindValue(':table_name', 'TEST', PDO::PARAM_STR);
$stmt->execute();
$row = $stmt->fetch(PDO::FETCH_ASSOC);
$stmt->closeCursor();
if ($row != FALSE && $row['CNT'] > 0) {
    $stmt = $db->prepare('DROP TABLE TEST');
    $stmt->execute();
    $stmt->closeCursor();
}

// TABLE作成
$stmt = $db->prepare('CREATE TABLE TEST(ID VARCHAR2(32) NOT NULL PRIMARY KEY, NAME VARCHAR2(2048))');
$stmt->execute();
$stmt->closeCursor();

// INSERT
$stmt = $db->prepare('INSERT INTO TEST (ID, NAME) VALUES (:id, :name)');
$stmt->bindValue(':id', 'shirogane', PDO::PARAM_STR);
$stmt->bindValue(':name', '白銀', PDO::PARAM_STR);
$stmt->execute();
$stmt->closeCursor();
output($db, 'INSERT');

// UPDATE
$stmt = $db->prepare('UPDATE TEST SET NAME = :name WHERE ID = :id');
$stmt->bindValue(':name', 'しろがね', PDO::PARAM_STR);
$stmt->bindValue(':id', 'shirogane', PDO::PARAM_STR);
$stmt->execute();
$stmt->closeCursor();
output($db, 'UPDATE');

// DELETE
$stmt = $db->prepare('DELETE FROM TEST WHERE ID = :id');
$stmt->bindValue(':id', 'shirogane', PDO::PARAM_STR);
$stmt->execute();
$stmt->closeCursor();
output($db, 'DELETE');

// DROP TABLE
$stmt = $db->prepare('DROP TABLE TEST');
$stmt->execute();
$stmt->closeCursor();

// 出力用関数
function output($db, $crud) {
    $stmt = $db->prepare('SELECT * FROM TEST WHERE ID = :id ORDER BY ID');
    $stmt->bindValue(':id', 'shirogane', PDO::PARAM_STR);
    $stmt->execute();
    $data = [];
    while (($row = $stmt->fetch(PDO::FETCH_ASSOC)) != false) {
        $data[] = $row;
    }
    $stmt->closeCursor();
    if (PHP_SAPI === 'cli') {
        echo $crud."\n".print_r($data, TRUE)."\n";
    } else {
        echo $crud.'<br><pre>'.print_r($data, TRUE).'</pre><br>';
    }
}
```
以下、実行結果  
(ORACLE_HOME、NLS_LANGは.bash_profileなどに書いておいてもよいかも)
```
$ env ORACLE_HOME=/opt/oracle/product/26ai/dbhomeFree NLS_LANG=Japanese_Japan.AL32UTF8 php84 test.php
INSERT
Array
(
    [0] => Array
        (
            [ID] => shirogane
            [NAME] => 白銀
        )

)

UPDATE
Array
(
    [0] => Array
        (
            [ID] => shirogane
            [NAME] => しろがね
        )

)

DELETE
Array
(
)

```

## 5. php-fpmから実行する例

最後にApacheとphp-fpmで実行する例  
php-fpmをインストール

```
$ sudo dnf install php84-php-fpm httpd
$ sudo vi /etc/opt/remi/php84/php-fpm.d/www-env.conf
[www]
env[ORACLE_HOME] = /opt/oracle/product/26ai/dbhomeFree
env[NLS_LANG] = Japanese_Japan.AL32UTF8
$ sudo systemctl enable php84-php-fpm --now
$ sudo systemctl enable httpd --now
```
/etc/opt/remi/php84/php-fpm.d/  
配下のconf(この例では、/etc/opt/remi/php84/php-fpm.d/www-env.conf)  
にORACLE_HOMEとNLS_LANG(日本語をきちんと表示するための環境変数設定)を追加  
であとは、DocumentRoot(デフォルトでは/var/www/html)に先程のtest.phpを置いて確認  
ブラウザでアクセスして、以下のような結果で日本語が表示されればOK  
```
INSERT
Array
(
    [0] => Array
        (
            [ID] => shirogane
            [NAME] => 白銀
        )

)

UPDATE
Array
(
    [0] => Array
        (
            [ID] => shirogane
            [NAME] => しろがね
        )

)

DELETE
Array
(
)
```

ここまでできれば完了です。お疲れ様でした。
