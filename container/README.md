# 検証コンテナ

## 1. コンテナの種類

RHEL系での検証として、

* CentOS Stream 9(RHEL直系)
* Oracle Linux 9(Oracle本家)
* ubi9(RHEL本家)

のコンテナで動作確認できるようにしています  
上記3種のコンテナで動作できれば、他のRHEL系ディストリビューションでも問題なく動くことが予想されるためです

## 2. 実行コマンド

私自身podmanを使用しているので、podmanでしか試していませんが、おそらくdockerでも同じかと思います

```
$ cd container/{各ディストリビューション}
$ podman build -f ./Dockerfile -t {タグ名}
$ podman run -it -p 8080:80 -p 1521:1521 -e ORACLE_PASSWD={パスワード} -e TZ={タイムゾーン} --name {プロセス名} {タグ名}
```
で実行  
ORACLE_PASSWDを指定し忘れても、実行後コンテナ内で、  
```
# env ORACLE_PASSWD={パスワード} entrypoint
```
を実行すれば、DBのセットアップは可能です  
実行後はブラウザで、  
http://localhost:8080/phpinfo.php  
http://localhost:8080/test.php  
にアクセスすれば、動作を確認できます  
dbeaverなどのDBツールを使用すれば、  
<table>
<tr><th>ユーザ名</th><th>パスワード</th><th>IPアドレス</th><th>ポート</th></tr>
<tr><td>TEST</td><td>runで指定したORACLE_PASSWDの値</td><td>localhost</td><td>1521(デフォルト)</td></tr>
</table>
でアクセスできます

## 2. コンテナ化に伴う苦労した点など

### 2-1. そもそもの目的

RHEL系で動かしたいというところは、1で述べた通りですが、  
```
ARG ORAPREINSTALLRPM
ARG ORAINSTALLRPM
```
で、Oracleのpreinstallと本体のRPMのURLを指定できれば、いろんなバージョンのOracle Databaseをインストールできるなと考えたのが最初でした  
そこでまずはFree 26aiでコンテナを作成してみたというのが始まりです  
次に、XE 21c
Remiリポジトリのphp84-php-pecl-pdo-ociが必要とする、libclntsh.soパッケージのバージョンと、Oracle本体のlibclntsh.soのバージョンが

* 同じなら、Fake Packageを作成
* 異なるなら、pecl installでコンパイル

というのを自動化できないかなと考えたのがきっかけです  
その環境を実現するために、Free 26aiとXE 21cに対応させました  
紆余曲折さまざまなことがありましたが、なんとかうまく実行させることができました

### 2-2. コンテナ作成におけるsu(wrapper)

まずはじめにOracle Linux 9をベースのOSにして、インストールすることを考えました  
公式のOSでもありますし、すぐに終わるだろうと踏んでいたのですが…

パッケージ自体のインストールは問題なかったのですが、entrypoint.shを動かして、データベースを初期化するところでハマりました  
これは、
```
# /etc/init.d/oracle-free-26ai configure
```
の際に、スクリプト中でsu(switch user)している箇所があり、ここでoracleユーザで実行しているためでした  
そこで、gosuをインストールしてsuをgosuで置き換えたのですが、suのオプションなどを細かく扱う必要があったため、  
suをsu wrapperで置き換えています  

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


### 2-2. ubi9編

一旦は、



