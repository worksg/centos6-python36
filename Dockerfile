FROM centos:6

ENV PYTHON_MINOR_VERSION 3.6
ENV PYTHON_PATCH_VERSION 10
ENV PYTHON_VERSION ${PYTHON_MINOR_VERSION}.${PYTHON_PATCH_VERSION}

ENV INSTALL_BASE /opt/python
ENV INSTALL_LOC $INSTALL_BASE/$PYTHON_VERSION

# ensure local python is preferred over distribution python
ENV PATH $INSTALL_LOC/bin:$PATH

## US English ##
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV LC_COLLATE C
ENV LC_CTYPE en_US.UTF-8

ENV GPG_KEY 0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D

# Start by making sure your system is up-to-date:
# Libraries needed during compilation to enable all features of Python:
RUN yum update -y ; \
    yum groupinstall -y "development tools" ; \
    yum install -y \
        zlib-devel \
        bzip2-devel \
        openssl-devel \
        ncurses-devel \
        sqlite-devel \
        readline-devel \
        tk-devel \
        gdbm-devel \
        db4-devel \
        libpcap-devel \
        xz-devel \
        expat-devel \
        gnupg \
        wget \
        ca-certificates ; \
    update-ca-trust force-enable

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 20.0.2

ARG PYTHON_DL_MIRROR

# install python3
RUN set -ex \
        && wget -O python.tar.xz "${PYTHON_DL_MIRROR:-https://www.python.org/ftp/python}/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" \
        && wget -O python.tar.xz.asc "${PYTHON_DL_MIRROR:-https://www.python.org/ftp/python}/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc" \
        && export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEY" \
	&& gpg --batch --verify python.tar.xz.asc python.tar.xz \
	&& rm -rf "$GNUPGHOME" python.tar.xz.asc \
	&& mkdir -p /usr/src/python \
	&& tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
	&& rm python.tar.xz \
	&& cd /usr/src/python \
        && ./configure \
                --prefix=$INSTALL_LOC \
                --enable-loadable-sqlite-extensions \
                --enable-optimizations \
                --enable-option-checking=fatal \
                --enable-shared \
                --with-system-expat \
                --with-system-ffi \
                --without-ensurepip \
                --with-computed-gotos \
                --enable-ipv6 \
                --libdir=$INSTALL_LOC/lib \
                CFLAGS="-g -fstack-protector --param=ssp-buffer-size=4 -Wformat -Werror=format-security" \
                LDFLAGS="-L$INSTALL_LOC/lib -Wl,-rpath=$INSTALL_LOC/lib " \
                CPPFLAGS="-I$INSTALL_LOC/include " \
        && make -j "$(nproc)" \
        && make altinstall \
        && ldconfig \
	&& rm -rf /usr/src/python

# make some useful symlinks that are expected to exist
RUN cd $INSTALL_LOC/bin \
	&& ln -s idle${PYTHON_MINOR_VERSION} idle \
	&& ln -s pydoc${PYTHON_MINOR_VERSION} pydoc \
	&& ln -s python${PYTHON_MINOR_VERSION} python3 \
	&& ln -s python${PYTHON_MINOR_VERSION}m-config python-config

ARG PIP_DL_MIRROR

RUN set -ex && \
	wget -O get-pip.py 'https://bootstrap.pypa.io/get-pip.py'; \
	\
	python3 get-pip.py ${PIP_DL_MIRROR:+-i ${PIP_DL_MIRROR}} \
		--disable-pip-version-check \
		--no-cache-dir \
		"pip==$PYTHON_PIP_VERSION" \
	; \
	pip --version; \
	\
	find /usr/local -depth \
		\( \
			\( -type d -a \( -name test -o -name tests -o -name idle_test \) \) \
			-o \
			\( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
		\) -exec rm -rf '{}' +; \
	rm -f get-pip.py


RUN pip install --no-cache-dir ${PIP_DL_MIRROR:+-i $PIP_DL_MIRROR} \
        virtualenv \
        pyinstaller

RUN yum -y clean all --enablerepo='*'

CMD ["/bin/bash"]
