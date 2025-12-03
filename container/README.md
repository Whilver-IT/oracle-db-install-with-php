# Oracle Database + PDO_OCI オールインワン・コンテナ奮闘記録

RHEL系コンテナで Oracle を動かすまでの「壮絶な戦い」

## 1. 対応コンテナについて

Oracle Database(Free 26ai / XE 21c)を **RHEL環境で"どこでも動く"** ようにするため

* CentOS Stream 9(RHEL直系)
* Oracle Linux 9(Oracle本家)
* UBI9(RHEL本家)

の3種類で動作検証を行いました
この3つが動けば、他のRHEL系(Alma /Rocky /OEL派生等)でも問題なく動くと判断しています

## 2. 実行方法(podman / docker共通)

普段podmanを使っていますが、おそらくdockerでも同じかと

```
$ cd container/{各ディストリビューション}
$ podman build -f ./Dockerfile -t {タグ名}
$ podman run -it -p 8080:80 -p 1521:1521 -e ORACLE_PASSWD={パスワード} -e TZ={タイムゾーン} --name {プロセス名} {タグ名}
```
で実行  
ORACLE_PASSWDを忘れた場合は、コンテナ内で
```
# env ORACLE_PASSWD={パスワード} entrypoint
```
を実行すれば、DBのセットアップが実行されます

動作確認はブラウザで、  
* http://localhost:8080/phpinfo.php  
* http://localhost:8080/test.php

DB接続例(DBeaver等)
<table>
<tr><th>ユーザ名</th><th>パスワード</th><th>IPアドレス</th><th>ポート</th></tr>
<tr><td>TEST</td><td>runで指定したORACLE_PASSWDの値</td><td>localhost</td><td>1521(デフォルト)</td></tr>
</table>

## 3. コンテナ化で苦労した点

ここからが本題  
**本当に地獄のような戦いだったので、記録として残しますw**

### 3-1. そもそもの発端

最初は軽い気持ちでした
```
ARG ORAPREINSTALLRPM
ARG ORAINSTALLRPM
```
これで、Oracleの色んなバージョンを試せるのでは!?
という考えから…

まず、Oracle Linux 9 + Free 26aiを作成  
インストールまでは問題なし

しかし、**entrypointのconfigure**が失敗
```
/etc/init.d/oracle-free-26ai configure
```
ここで、su/gosu問題に直面

### 3-2. suのwrapper地獄

PostgreSQLの経験から、gosuを使えばいけると思ったのですが…  
**Oracleのinit scriptはsuの使い方が特殊で、普通にgosu差し替えでは動かない**ようです

そこで、suをラッピングしてオプションをパースし直す「su wrapper」戦略へ
```
mv /bin/su /bin/su.default; \
echo "#!/bin/bash" > /usr/local/bin/su; \
echo 'if [[ "$*" == *" -c "* ]]; then' >> /usr/local/bin/su; \
echo '  user=$(echo "$@" | awk '\''{for(i=1;i<=NF;i++) if($i!="-" && $i!="-s" && $i!="/bin/bash" && $i!="-c"){print $i; exit}}'\'')' >> /usr/local/bin/su; \
echo '  cmd=$(echo "$@" | sed -E '\''s/.* -c (.*)/\1/'\'')' >> /usr/local/bin/su; \
echo '  exec /usr/local/bin/gosu "$user" bash -c "$cmd"' >> /usr/local/bin/su; \
echo "else" >> /usr/local/bin/su; \
echo '  exec /usr/local/bin/gosu "$@"' >> /usr/local/bin/su; \
echo "fi" >> /usr/local/bin/su; \
chmod +x /usr/local/bin/su; \
ln -sf /usr/local/bin/su /bin/su
```
とDockerfile上でechoを使用して完結させていますが、
```
#!/bin/bash
if [[ "$*" == *" -c "* ]]; then
  user=$(echo "$@" | awk '{for(i=1;i<=NF;i++) if($i!="-" && $i!="-s" && $i!="/bin/bash" && $i!="-c"){print $i; exit}}')
  cmd=$(echo "$@" | sed -E 's/.* -c (.*)/\1/')
  exec /usr/local/bin/gosu "$user" bash -c "$cmd"
else
  exec /usr/local/bin/gosu "$@"
fi
```
といったファイルをコピーする方法でもうまくいくと思います  
最終的に正しくsu wrapperを作成し、configureが通るようにしました

### 3-3. UBI9コンテナでの戦い

preinstallが依存まみれ  
→ CentOS Stream 9パッケージで補完

UBI9のrootfsだけではpreinstallの依存が解決できず、CentOS Stream 9のRPMを部分的に使用してお茶濁し…

でもこの段階で、  
**OL9とUBI9で共通化できるentrypointが完成**

### 3-4. CentOS Stream 9コンテナは素直

```
FROM quay.io/centos/centos:stream9
```
にしただけで成功w  
ここから始まるさらなる地獄が起きようとは…このときはまだ知る由もなかったのですw

### 3-5. Oracle XE 21c対応で再び沼へ

次に、UBI9で
```
ARG=ORAPREINSTALLRPM=https://yum.oracle.com/repo/OracleLinux/OL8/appstream/x86_64/getPackage/oracle-database-preinstall-21c-1.0-1.el8.x86_64.rpm
ARG ORAINSTALLRPM=https://download.oracle.com/otn-pub/otn_software/db-express/oracle-database-xe-21c-1.0-1.ol8.x86_64.rpm
```
と、XE 21cを対応させることにしました  
ここで、Remiリポジトリのphp84-php-pecl-pdo-ociが必要とする、libclntsh.soパッケージのバージョンと、  
Oracle本体のlibclntsh.soのバージョンが同じでないと、Fake Packageを作成してもうまく動作しないことが分かりました([README](../README.md#6-fake-packagelibclntshsoを作り始めた理由))

ならば、  

* バージョンが同じなら、Fake Packageを作成
* バージョンが異なるなら、pecl installでコンパイル

というのを自動化できないかなと考えました  
libclntsh.soのバージョンで処理を分けたり、Free 26aiとXE 21cで対応するパッケージに過不足があるなどの問題もありましたが、なんとかうまく実行させることができました

### 3-6. 本当のラスボス：OL9コンテナのconfigure失敗

UBI9がうまくいったので、まさか本家であるOL9など恐れるに足らずと思っていました  
実際にインストールまでは問題なくいったのですが、ここからが地獄の始まりになろうとは…  

**configureが毎回失敗してしまう**

本家なのに動かない…wwww

でも、OL9.2(ISO)で問題なく動いてた記憶はありました([Oracle-XE-21cインストール.md](https://github.com/Whilver-IT/crazyframework/blob/main/Oracle-XE-21cインストール.md))  
→ VirtualBoxで実験  
→ やはりOL9.2ならXE 21cのconfigureが成功

そこで、4環境でrpmを比較  
* OL9.2 (最小構成インストール)
* OL9.2 (XE 21cインストール後)
* OL9コンテナ
* UBI9コンテナ

比較表([OL9-comparing-rpm-package.xlsx](OL9-comparing-rpm-packages.xlsx))で差分を見てみました

はじめは、OL9.2の最小構成インストールとOL9.2のXE 21cインストール後で差異のあった、  
**sssd-nfs-idmap**  
を疑いましたがこれではありませんでした

次に、OL9.2のXE 21cインストール後、ubi9のXE 21cインストール後では共通かつ、OL9コンテナのXE 21cインストール後にはないパッケージを確認したところ、

以下の5つ

* **gobject-introspection**
* **json-glib**
* **libusbx**
* **libxcrypt-compat**
* **python-unversioned-command**

これらをインストールしてみたところ、ようやくconfigureが通りました  

しかし、本当に必要なのはどれか  
→ 1つずつ削除してその度にconfigureを実行する修行へw
→ configureが失敗すればそのパッケージは必須対象

そして、ついに結論

犯人は**libxcrypt-compat**ただ1つ
(この瞬間はマジで勝利の雄叫びレベルwww)

### 3-7. Oracleのrootfsだけlibxcrypt-compatが欠けているという衝撃の事実

OL9.2 ISO → 入ってる(ちなみに9.7のISOでも入ってますw)
OL9コンテナのrootfs (公式) → 入ってない

だから、コンテナ版だけconfigureが失敗  
ここに辿り着くまでの道のりは長すぎたwww

### 3-8. XE 18cでの最終検証

* libnsl(dnf)
* compat-libstdc++([CentOS Buildlogs Mirror](https://buildlogs.centos.org/c7.01.00/compat-gcc-32/20150305224037/3.2.3-72.el7.x86_64/))
* compat-libcap1([CentOS Buildlogs Mirror](https://buildlogs.centos.org/c7.00.02/compat-libcap1/20140529185543/1.10-7.el7.x86_64/))

からインストールすれば、XE 18cもOL9コンテナにインストールは可能  
だが、オススメはしないw

## そして旅は終わった

libxcrypt-compatというラスボスを倒し、RHEL系コンテナ3種すべてでOracle + PCO_OCIが動作
