PACKAGES  = --pkg gee-1.0 --pkg glib-2.0 --pkg gio-2.0 --pkg gtk+-3.0 --pkg libudev --pkg appindicator3-0.1

CC    = valac
CFLAGS    = --vapidir vapis --debug --thread $(PACKAGES) --target-glib=2.32
SOURCES = *.vala
SOURCES   +=  *.c

BINARYDIR = binary/
BINARY    = android-mtp-indicator


all: AndroidMTPIndicator
	@echo sucessfully compiled

install: all $(MISCDIR)$(ICON)
	cp $(BINARYDIR)$(BINARY) /usr/bin/$(BINARY)
	@echo sucessfully installed

uninstall:
	rm /usr/bin/$(BINARY)
	@echo sucessfully uninstalled

clean:
	rm $(BINARYDIR)$(BINARY)
	@echo sucessfully cleaned

linecount:
	wc --lines $(SOURCES)
	
run:
	$(BINARYDIR)$(BINARY)

###############################################################################
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!#
###############################################################################


AndroidMTPIndicator: $(BINARYDIR)
	$(CC) $(CFLAGS) $(SOURCES) -o $(BINARYDIR)$(BINARY)

$(BINARYDIR):
	mkdir -p $(BINARYDIR)