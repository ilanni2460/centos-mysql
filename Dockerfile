FROM centos:7
MAINTAINER Percona Development <info@percona.com>

RUN export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A \
	&& gpg --export --armor 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A > ${GNUPGHOME}/RPM-GPG-KEY-Percona \
	&& rpmkeys --import ${GNUPGHOME}/RPM-GPG-KEY-Percona /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7 \
	&& curl -L -o /tmp/percona-release.rpm http://www.percona.com/downloads/percona-release/redhat/0.1-6/percona-release-0.1-6.noarch.rpm \
	&& rpmkeys --checksig /tmp/percona-release.rpm \
	&& yum install -y /tmp/percona-release.rpm \
	&& rm -rf "$GNUPGHOME" /tmp/percona-release.rpm

# install exact version of PS for repeatability
ENV PERCONA_VERSION 5.7.24-26.1.el7

RUN yum install -y \
		Percona-Server-server-57-${PERCONA_VERSION} \
		Percona-Server-tokudb-57-${PERCONA_VERSION} \
		Percona-Server-rocksdb-57-${PERCONA_VERSION} \
		jemalloc \
		which \
		policycoreutils \
	&& yum clean all \
	&& rm -rf /var/cache/yum /var/lib/mysql

# purge and re-create /var/lib/mysql with appropriate ownership
RUN /usr/bin/install -m 0775 -o root -g root -d /var/lib/mysql /var/run/mysqld /docker-entrypoint-initdb.d \
# comment out a few problematic configuration values
	&& find /etc/percona-server.cnf /etc/percona-server.conf.d /etc/my.cnf.d -name '*.cnf' -print0 \
		| xargs -0 grep -lZE '^(bind-address|log|user)' \
		| xargs -rt -0 sed -Ei 's/^(bind-address|log|user)/#&/' \
# don't reverse lookup hostnames, they are usually another container
	&& printf '[mysqld]\nskip-host-cache\nskip-name-resolve\n' > /etc/my.cnf.d/docker.cnf \
# TokuDB modifications
	&& /usr/bin/install -m 0664 -o root -g root /dev/null /etc/sysconfig/mysql \
	&& echo "LD_PRELOAD=/usr/lib64/libjemalloc.so.1" >> /etc/sysconfig/mysql \
	&& echo "THP_SETTING=never" >> /etc/sysconfig/mysql \
# keep backward compatibility with debian images
	&& ln -s /etc/my.cnf.d /etc/mysql \
# allow to change config files
	&& chown -R root:root /etc/percona-server.cnf /etc/percona-server.conf.d /etc/my.cnf.d \
	&& chmod -R ug+rwX /etc/percona-server.cnf /etc/percona-server.conf.d /etc/my.cnf.d

VOLUME ["/var/lib/mysql", "/var/log/mysql"]

COPY ps-entry.sh /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]

USER mysql
EXPOSE 3306
CMD ["mysqld"]
