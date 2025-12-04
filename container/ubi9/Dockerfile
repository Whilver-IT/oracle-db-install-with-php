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
fi

# libclntsh-fake-packageを含めてbuildステージから必要なファイルを持ってきて生成
FROM registry.access.redhat.com/ubi9/ubi-minimal:latest

# ロケールのデフォルトはja_JP.UTF-8
ARG LANG=ja_JP.UTF-8

# GOSUのバージョンを指定
ENV GOSU_VERSION=1.18

# ローカルのentrypoint.shとbuildステージで格納、生成したファイルをコンテナにコピー
COPY entrypoint.sh /usr/local/bin/entrypoint
COPY --from=build /tmp/remi-release.rpm /tmp/remi-release.rpm
COPY --from=build /tmp/epel-release.rpm /tmp/epel-release.rpm
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
ADDDNFRPM=""; \
FAKEPKGRPM=""; \
NEEDXEPKGS=""; \
# fake-packageの容量が0かそうでないかでパッケージを分ける
ISUSEFAKEPKG=0; \
if [ -s /tmp/libclntsh-fake-package.noarch.rpm ]; then \
  ISUSEFAKEPKG=1; \
  FAKEPKGRPM="/tmp/libclntsh-fake-package.noarch.rpm"; \
  ADDDNFRPM="php84-php-pecl-oci8"; \
fi; \
# XEかどうかを確認し、そうならcompat-openssl10とlibnslを入れる
if rpm -qlp /tmp/oracle-db.rpm | grep -q dbhomeXE$; then \
  ADDDNFRPM=" ${ADDDNFRPM} iproute"; \
  # libnslバージョンがAlma9のでないと合わないので
  NEEDXEPKGS="\
    https://cdn-ubi.redhat.com/content/public/ubi/dist/ubi8/8/x86_64/appstream/os/Packages/c/compat-openssl10-1.0.2o-4.el8_10.1.x86_64.rpm \
    https://repo.almalinux.org/almalinux/9/BaseOS/x86_64/os/Packages/libnsl-2.34-231.el9_7.2.x86_64.rpm"; \
else \
  ADDDNFRPM=" ${ADDDNFRPM} compat-openssl11"; \
fi; \
# パッケージのインストール
rpm -ivh \
/tmp/remi-release.rpm \
/tmp/epel-release.rpm \
${FAKEPKGRPM}; \
microdnf upgrade -y; \
microdnf reinstall -y tzdata; \
# httpd-coreはphp84-phpで入るので、敢えてここでは指定していない
microdnf install -y \
${ADDDNFRPM} \
php84-php \
php84-php-pdo \
glibc-locale-source \
bc \
bind-utils \
binutils \
ethtool \
fontconfig \
glibc-devel \
hostname \
initscripts \
libaio \
libxcrypt-compat \
make \
module-init-tools \
net-tools \
openssh-clients \
pam \
policycoreutils \
policycoreutils-python-utils \
procps \
psmisc \
tar \
unzip \
util-linux-ng \
xorg-x11-xauth \
keyutils \
device-mapper \
libtirpc \
python3-pyyaml \
libpath_utils \
avahi-libs \
lm_sensors-libs \
xz \
file; \
# 以下の依存解決は仕方なくCentOS Stream9のパッケージでお茶を濁しておくw
# rpmのURLがバージョンアップなどで、ダウンロードできなくなる可能性はあることに注意
env ORACLE_DOCKER_INSTALL=true rpm -ivh \
${NEEDXEPKGS} \
https://mirror.stream.centos.org/9-stream/AppStream/x86_64/os/Packages/ksh-1.0.6-14.el9.x86_64.rpm \
https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/nfs-utils-2.5.4-39.el9.x86_64.rpm \
https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/libnfsidmap-2.5.4-39.el9.x86_64.rpm \
https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/e2fsprogs-libs-1.46.5-8.el9.x86_64.rpm \
https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/quota-nls-4.09-4.el9.noarch.rpm \
https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/quota-4.09-4.el9.x86_64.rpm \
https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/rpcbind-1.2.6-7.el9.x86_64.rpm \
https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/libbasicobjects-0.1.1-53.el9.x86_64.rpm \
https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/libcollection-0.7.0-53.el9.x86_64.rpm \
https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/libref_array-0.1.5-53.el9.x86_64.rpm \
https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/libini_config-1.3.1-53.el9.x86_64.rpm \
https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/libev-4.33-6.el9.x86_64.rpm \
https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/libverto-libev-0.3.2-3.el9.x86_64.rpm \
https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/gssproxy-0.8.4-7.el9.x86_64.rpm \
https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/smartmontools-7.2-9.el9.x86_64.rpm \
https://mirror.stream.centos.org/9-stream/AppStream/x86_64/os/Packages/pcp-conf-6.3.7-5.el9.x86_64.rpm \
https://mirror.stream.centos.org/9-stream/AppStream/x86_64/os/Packages/pcp-libs-6.3.7-5.el9.x86_64.rpm \
https://mirror.stream.centos.org/9-stream/AppStream/x86_64/os/Packages/sysstat-12.5.4-9.el9.x86_64.rpm \
https://mirror.stream.centos.org/9-stream/AppStream/x86_64/os/Packages/libXxf86dga-1.1.5-8.el9.x86_64.rpm \
https://mirror.stream.centos.org/9-stream/AppStream/x86_64/os/Packages/libdmx-1.1.4-12.el9.x86_64.rpm \
https://mirror.stream.centos.org/9-stream/AppStream/x86_64/os/Packages/xorg-x11-utils-7.5-40.el9.x86_64.rpm \
# ビルドステージから持ってきたOracleをここで指定
/tmp/oracle-preinstall.rpm \
/tmp/oracle-db.rpm; \
# コピーしてきた/tmpにあるrpmを削除
rm -f /tmp/oracle-preinstall.rpm /tmp/oracle-db.rpm /tmp/libclntsh-fake-package.noarch.rpm /tmp/remi-release.rpm /tmp/epel-release.rpm; \
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
  # peclでコンパイルするためのパッケージ追加
  microdnf install dnf -y; \
  dnf upgrade -y; \
  dnf install -y \
  php84-php-devel \
  php84-php-pear \
  gcc \
  autoconf; \
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
  rpm -e dnf; \
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
