PWD:=$(shell pwd)
BUILD_DIR?=$(PWD)/guac-out
LDCONFIG_FREERDP=$(shell pkg-config $(shell find $(BUILD_DIR) -name freerdp.pc) --libs-only-L)
CFLAGS_FREERDP=$(shell pkg-config $(shell find $(BUILD_DIR) -name freerdp.pc) --cflags)
MAKE_CPU=8
MKTEMP=$(shell mktemp -d)

all: libguac freerdp libguac-client-rdp guacd mvn conf auth

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

libguac-prep:
	cd libguac; aclocal
	cd libguac; libtoolize
	cd libguac; autoconf
	cd libguac; automake -a
	cd libguac; ./configure --prefix=$(BUILD_DIR)

libguac-build: $(BUILD_DIR) libguac-prep
	make -C libguac -j $(MAKE_CPU)

libguac-install: libguac-build
	cd libguac; make install

libguac: libguac-install

libguac-clean:
	make -C libguac distclean


freerdp-prep:
	cd freerdp; cmake -DCMAKE_INSTALL_PREFIX=$(BUILD_DIR) -DCMAKE_BUILD_TYPE=Release -DWITH_ULTEO_PDF_PRINTER=ON -DWITH_CUPS=OFF -DWITH_X11=OFF -DWITH_XCURSOR=OFF -DWITH_XEXT=OFF -DWITH_XINERAMA=OFF -DWITH_XV=OFF -DWITH_XKBFILE=OFF -DWITH_FFMPEG=OFF -DWITH_ALSA=OFF

freerdp-build: freerdp-prep
	cd freerdp; make -j $(MAKE_CPU)

freerdp-install: freerdp-build
	make -C freerdp install

freerdp: freerdp-install


libguac-client-rdp-prep: 
	cd libguac-client-rdp; aclocal
	cd libguac-client-rdp; libtoolize
	sed -i 's/AC_FUNC_MALLOC/#AC_FUNC_MALLOC/' libguac-client-rdp/configure.in 
	cd libguac-client-rdp; autoconf
	cd libguac-client-rdp; automake -a
	cd libguac-client-rdp; LDFLAGS="-L$(BUILD_DIR)/lib $(LDCONFIG_FREERDP)" CFLAGS="$(CFLAGS_FREERDP)" ./configure --prefix=$(BUILD_DIR)

libguac-client-rdp-build: libguac-client-rdp-prep
	make -C libguac-client-rdp -j $(MAKE_CPU)

libguac-client-rdp-install: libguac-client-rdp-build
	make -C libguac-client-rdp install

libguac-client-rdp: libguac-client-rdp-install


guacd-prep:
	cd guacd; aclocal
	cd guacd; autoconf
	cd guacd; automake -a
	cd guacd; LDFLAGS="-L$(BUILD_DIR)/lib" CFLAGS="-I$(BUILD_DIR)/include" ./configure --with-init-dir=$(BUILD_DIR)/etc/init.d --prefix=$(BUILD_DIR)

guacd-build: guacd-prep
	make -C guacd

guacd-install: guacd-build
	make -C guacd install

guacd: guacd-install


mvn:
	cd common; mvn -B package
	cd common; mvn -B install
	cd common-auth; mvn -B package
	cd common-auth; mvn -B install
	cd common-js; mvn -B package
	cd common-js; mvn -B install
	cd guacamole; mvn -B package
	cd guacamole; mvn -B install
	cp guacamole/target/guacamole-default-webapp-0.6.0.war $(BUILD_DIR)


conf:
	cp guacamole/doc/example/guacamole.properties $(BUILD_DIR)
	sed -i 's/auth-provider:.*$$/auth-provider: net.sourceforge.guacamole.net.auth.ovd.UlteoOVDAuthenticationProvider/' $(BUILD_DIR)/guacamole.properties
	sed -i 's/basic-user-mapping:.*$$//' $(BUILD_DIR)/guacamole.properties


auth:
	cd auth-ulteo-ovd; mvn package
	$(eval TMP := $(MKTEMP))
	mkdir $(TMP)/guacamole-ulteo
	tar xvzf auth-ulteo-ovd/target/guacamole-auth-ulteo-ovd-0.6.0.tar.gz -C $(TMP)/
	cp $(TMP)/guacamole-auth-ulteo-ovd-0.6.0/lib/* $(TMP)/guacamole-ulteo/
	### règle un problème de classe introuvable
	sed -i 's/GuacamoleServerException/Exception/' printing/src/main/java/net/sourceforge/guacamole/net/printing/GuacamolePrinterServlet.java
	cd printing; mvn package
	tar xvzf printing/target/guacamole-printing-0.6.0.tar.gz -C $(TMP)/
	cp $(TMP)/guacamole-printing-0.6.0/lib/* $(TMP)/guacamole-ulteo/
	cd $(TMP)/guacamole-ulteo; tar cvjf $(BUILD_DIR)/guacamole-ulteo.tar.bz2 *.jar
	rm -rf $(TMP)
