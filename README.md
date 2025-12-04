# Oracle Databaseをインストールし、PDO_OCIでOracleを操作する

## 1. ライセンスについて

MITライセンスとします  
本プログラム等を使用して発生したいかなる不具合にも責任を負いません  
また、ビルドステージのコンテナ内には、OracleのRPM(preinstall / database本体)を一時的に取り扱います、  
これらのパッケージ自体は改変禁止です

## 2. 対応バージョン

* Oracle Free 26ai
* Oracle Database XE 21c  
※XE 18cの動作自体は確認してますが未対応

XEはそもそもOracle Linux 9対応パッケージが存在しません  
そのため使用には注意してください  
また、Dockerfile中のURLは公式都合で予告なく変更されることがあります

Oracle公式のコンテナも存在しますので、用途に応じてご検討ください  
```
docker pull container-registry.oracle.com/database/free:latest
```

## 3. そもそもの目的

もともとLinux1台に、DB(Oracle)、Apache、php(PDOを使用)を全部まとめたいと考えていました  
ちょうどOracle Free 26aiがリリースされたこと  
そして、2024年8月に[PDO_OCI](https://pecl.php.net/package/pdo_oci)が更新され、
Remiリポジトリにもphp84-pecl-pdo-ociが追加されたことで  

**もしかして今なら全部入り環境作成できるのでは!?**

という期待から、検証を開始しました  
2023年にも挑戦しましたが、当時はPDO_OCI古く未対応だったため、思うような環境構築ができませんでした
* [Oracle XE 21cをインストールして最低限使うところまで](https://github.com/Whilver-IT/crazyframework/blob/main/Oracle-XE-21c%E3%82%A4%E3%83%B3%E3%82%B9%E3%83%88%E3%83%BC%E3%83%AB.md)  
* [PDO_OCIを使用してOracleを操作する](https://github.com/Whilver-IT/crazyframework/blob/main/PDO_OCI%E3%82%92%E3%82%A4%E3%83%B3%E3%82%B9%E3%83%88%E3%83%BC%E3%83%AB%E3%81%97%E3%81%A6Oracle%E3%81%AE%E6%93%8D%E4%BD%9C.md)  

今回ようやくそのリベンジが果たせました  
が、コンテナ化は地獄でした(でも楽しかったw)

## 4. インストールガイド

* Oracle Free 26aiのインストール ([oracle-database-free.md](oracle-database-free.md))  
* PHPからPDO_OCIを使用しての操作 ([php-connect-oracle.md](php-connect-oracle.md))  

## 5. コンテナについて

各種Dockerfileや構成は[container](container)フォルダを参照ください

## 6. Fake Package(libclntsh.so)を作り始めた理由

元々は「PHPからOracleに接続するには、Oracle InstantClientが必須」だと思い込んでいました  
さらに、Remiのphp84-pecl-pdo-ociが  
**libclntsh.soの依存解決に失敗 = Oracle InstantClientが必須**  
と勘違いしていたのもあります  
しかし実際は、  
* Oracle Database本体(dbhome)にも、libclntsh.soは入っている
* oci8のコンパイル時、ORACLE_HOMEを指定できる
* Oracle InstantClientを必ずしも使う必要はない

という事実に気付きました  
PECLの案内メッセージにもちゃんと書いてあります
```
Please provide the path to the ORACLE_HOME directory. Use 'instantclient,/path/to/instant/client/lib' if you're compiling with Oracle Instant Client [autodetect] : 
```
(昔の自分に言ってやりたいw)

<span style="font-size: 24px">Remiの依存バージョンとOracleのlibclntsh.soのバージョンが一致すると、Fake Packageが活きる!!</span>  

RemiのRPM依存にある：
```
libclntsh.so.<version>
```
と  
Oracleのパッケージに含まれる
```
$ORACLE_HOME/lib/libclntsh.so.<version>.1
```
が**一致している場合のみ**Fake Packageが有効です  
この仕組みを使うことで、

* Oracle InstantClient不要
* Remiのpecl-oci8、pecl-pdo-ociパッケージがそのまま使用できる
* pecl installすることなくPDOが動く

という、オールインワン構成が実現できました  
逆に、例えばXE 21cの場合、
```
ln -s libclntsh.so.21.1 libclntsh.so.23.1
```
のような、無理やりバージョンを合わせるようなやり方では動きませんでした

