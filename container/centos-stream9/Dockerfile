# Oracleのパッケージのダウンロードとlibclntsh-fake-packageパッケージを作成するためのステージ
FROM registry.access.redhat.com/ubi9/ubi-minimal:latest AS build

ARG ORAPREINSTALLRPM=https://yum.oracle.com/repo/OracleLinux/OL9/appstream/x86_64/getPackage/oracle-ai-database-preinstall-26ai-1.0-1.el9.x86_64.rpm
ARG ORAINSTALLRPM=https://download.oracle.com/otn-pub/otn_software/db-free/oracle-ai-database-free-26ai-23.26.0-1.el9.x86_64.rpm
#ARG ORAPREINSTALLRPM=https://yum.oracle.com/repo/OracleLinux/OL8/appstream/x86_64/getPackage/oracle-database-preinstall-21c-1.0-1.el8.x86_64.rpm
#ARG ORAINSTALLRPM=https://download.oracle.com/otn-pub/otn_software/db-express/oracle-database-xe-21c-1.0-1.ol8.x86_64.rpm

RUN set -eux; \
# remiとepel-releaseをダウンロード
curl -L https://rpms.remirepo.net/enterprise/remi-release-9.rpm -o /tmp/remi-release.rpm; \
curl -L https://dl.fedoraproject.org/pub/epel/9/Everything/x86_64/Packages/e/epel-release-9-10.el9.noarch.rpm -o /tmp/epel-release.rpm; \
# Oracleのパッケージをダウンロード
curl -L ${ORAPREINSTALLRPM} -o /tmp/oracle-preinstall.rpm; \
curl -L ${ORAINSTALLRPM} -o /tmp/oracle-db.rpm; \
# Oracleパッケージのlibclntsh.soのバージョンを取得
ORA_LIBCLNTSH_VERSION=$(rpm -qlp /tmp/oracle-db.rpm | grep -oP '(?<=/lib/libclntsh\.so\.).+(?=\.1$)' | tail -n 1); \
# remiからphp84-php-pecl-pdo-ociを持ってきてlibclntsh.soのバージョンを取得
rpm -ivh \
/tmp/remi-release.rpm \
/tmp/epel-release.rpm; \
microdnf upgrade -y; \
microdnf download php84-php-pecl-pdo-oci; \
REMI_LIBCLNTSH_VERSION=$(rpm -qRp *.rpm | grep -oP 'libclntsh\.so\.\K[0-9]+'); \
rpm -e remi-release epel-release; \
rm -f *.rpm; \
if [ "${ORA_LIBCLNTSH_VERSION}" -eq "${REMI_LIBCLNTSH_VERSION}" ]; then \
  # remiパッケージのlibclntsh.soとOracleのlibclntsh.soのバージョンが等しいときのみfakeパッケージを作成
  # 依存を消せないので、dnfを持ってきて使うことでお茶を濁しておくw
  microdnf install -y dnf; \
  dnf install -y rpmdevtools; \
  rpmdev-setuptree; \
  SPEC=~/rpmbuild/SPECS/libclntsh-fake-package-${REMI_LIBCLNTSH_VERSION}.1-1.spec; \
  echo "Name: libclntsh-fake-package" > ${SPEC}; \
  echo "Version: ${REMI_LIBCLNTSH_VERSION}.1" >> ${SPEC}; \
  echo "Release: 1%{?dist}.whilver" >> ${SPEC}; \
  echo "Summary: Fake package to provide libclntsh.so.${REMI_LIBCLNTSH_VERSION}.1 dependancy" >> ${SPEC}; \
  echo "License: Public Domain" >> ${SPEC}; \
  echo "BuildArch: noarch" >> ${SPEC}; \
  echo "Provides: libclntsh.so.${REMI_LIBCLNTSH_VERSION}.1()(64bit)" >> ${SPEC}; \
  echo "Provides: libclntsh.so.${REMI_LIBCLNTSH_VERSION}()(64bit)" >> ${SPEC}; \
  echo "Provides: libclntsh" >> ${SPEC}; \
  echo "%description" >> ${SPEC}; \
  echo "Fake package prividing the libclntsh.so.${REMI_LIBCLNTSH_VERSION}.1 dependancy" >> ${SPEC}; \
  echo "Contains no files" >> ${SPEC}; \
  echo "%prep" >> ${SPEC}; \
  echo "%build" >> ${SPEC}; \
  echo "%install" >> ${SPEC}; \
  echo "%files" >> ${SPEC}; \
  rpmbuild -ba ${SPEC}; \
  mv $(find ~/rpmbuild/RPMS -type f | grep libclntsh | head -n 1) /tmp/libclntsh-fake-package.noarch.rpm; \
  dnf remove -y rpmdevtools; \
  dnf autoremove -y; \
  rpm -e dnf; \
  rm -rf ~/rpmbuild; \
else \
  # バージョンが異なる場合は空のファイルを作成
  touch /tmp/libclntsh-fake-package.noarch.rpm; \
fi; \
rm /tmp/epel-release.rpm

# libclntsh-fake-packageを含めてbuildステージから必要なファイルを持ってきて生成
FROM quay.io/centos/centos:stream9

# ロケールのデフォルトはja_JP.UTF-8
ARG LANG=ja_JP.UTF-8

# GOSUのバージョンを指定
ENV GOSU_VERSION=1.18

# ローカルのentrypoint.shとbuildステージで格納、生成したファイルをコンテナにコピー
COPY entrypoint.sh /usr/local/bin/entrypoint
COPY --from=build /tmp/remi-release.rpm /tmp/remi-release.rpm
COPY --from=build /tmp/oracle-preinstall.rpm /tmp/oracle-preinstall.rpm
COPY --from=build /tmp/oracle-db.rpm /tmp/oracle-db.rpm
COPY --from=build /tmp/libclntsh-fake-package.noarch.rpm /tmp/libclntsh-fake-package.noarch.rpm

RUN set -eux; \
chmod +x /usr/local/bin/entrypoint; \
# gosuのダウンロード、設定
UNAME_ARCH=`uname -m`; \
case "${UNAME_ARCH}" in \
  x86_64) \
    GOSU_ARCH="amd64" ;; \
  aarch64) \
    GOSU_ARCH="arm64" ;; \
  *) \
    echo >&2 "error: unsupported architecture; '${UNAME_ARCH}'" exit 1 ;; \
esac; \
curl -L "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-${GOSU_ARCH}" -o /usr/local/bin/gosu; \
curl -L "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-${GOSU_ARCH}.asc" -o /usr/local/bin/gosu.asc; \
export GNUPGHOME="$(mktemp -d)"; \
gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
chmod +x /usr/local/bin/gosu; \
gosu --version; \
gosu nobody true; \
SETPKGS=""; \
# fake-packageの容量が0かそうでないかでパッケージを分ける
ISUSEFAKEPKG=0; \
if [ -s /tmp/libclntsh-fake-package.noarch.rpm ]; then \
  ISUSEFAKEPKG=1; \
  SETPKGS="\
    ${SETPKGS} \
    php84-php-pecl-oci8 \
    /tmp/libclntsh-fake-package.noarch.rpm"; \
else \
  SETPKGS="\
    php84-php-devel \
    php84-php-pear \
    gcc \
    autoconf"; \
fi; \
# XEかどうかを確認し、そうならcompat-openssl10、iproute、libxcrypt-compatを入れる
# Oracle XE 21cのconfigureでlibxcrypt-compatがないとエラーとなる
if rpm -qlp /tmp/oracle-db.rpm | grep -q dbhomeXE$; then \  
  SETPKGS="\
    ${SETPKGS} \
    iproute \
    libxcrypt-compat \
    https://yum.oracle.com/repo/OracleLinux/OL8/appstream/x86_64/getPackage/compat-openssl10-1.0.2o-4.el8_10.1.x86_64.rpm"; \
fi; \
# パッケージのインストール
dnf install -y /tmp/remi-release.rpm; \
dnf upgrade -y; \
# httpd_coreはphp84-phpの依存でインストールされるため、敢えて記述していない
env ORACLE_DOCKER_INSTALL=true \
dnf install -y \
/tmp/oracle-preinstall.rpm \
/tmp/oracle-db.rpm \
glibc-locale-source \
hostname \
php84-php \
php84-php-pdo \
${SETPKGS}; \
# コピーしてきた/tmpにあるrpmを削除
rm -f \
/tmp/oracle-preinstall.rpm \
/tmp/oracle-db.rpm \
/tmp/libclntsh-fake-package.noarch.rpm \
/tmp/remi-release.rpm; \
# 言語関連設定
localedef -i "${LANG%.*}" -f "${LANG##*.}" "$LANG"; \
echo LANG=${LANG} > /etc/locale.conf; \
export LANG=${LANG}; \
export LC_ALL=${LANG}; \
# ORACLE_HOMEを一旦ここでセット
ORACLE_HOME=$(find /opt/oracle/product -maxdepth 2 -type d | grep dbhome | head -n 1); \
# FAKEPKGを使用するかどうかで処理を分ける
if [ "${ISUSEFAKEPKG}" -eq 1 ]; then \
  echo "${ORACLE_HOME}/lib" > /etc/ld.so.conf.d/oracle.conf; \
  ldconfig; \
else \
  # コンパイル
  echo ${ORACLE_HOME} > /tmp/oraclehome; \
  /opt/remi/php84/root/bin/pecl install oci8 < /tmp/oraclehome; \
  echo "extension=oci8.so" > /etc/opt/remi/php84/php.d/20-oci8.ini; \
  /opt/remi/php84/root/bin/pecl install pdo_oci < /tmp/oraclehome; \
  echo "extension=pdo_oci.so" > /etc/opt/remi/php84/php.d/40-pdo_oci.ini; \
  # 後始末
  rm /tmp/oraclehome; \
  dnf remove -y \
  php84-php-devel \
  php84-php-pear \
  gcc \
  autoconf; \
  dnf autoremove -y; \
fi; \
# su wrapper
# Oracleインストール時には単純にsuをgosuにするだけだけではうまくいかないので、
# su時のオプション等をうまく反映させるsuのwrapperを生成
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

# phpの確認用ファイルを/var/www/htmlにコピー
COPY phpinfo.php /var/www/html/phpinfo.php
COPY test.php /var/www/html/test.php

EXPOSE 1521
EXPOSE 80
CMD ["entrypoint"]
