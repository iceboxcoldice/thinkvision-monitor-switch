CC = swiftc
SWIFT_FLAGS = -O -framework IOKit -framework Foundation
TARGET = monitor_usb_sync
SRC = src/monitor_usb_sync.swift

INSTALL_BIN_DIR = $(HOME)/.local/bin
SCRIPTS_DIR = $(HOME)/scripts
LAUNCH_AGENTS_DIR = $(HOME)/Library/LaunchAgents
PLIST_NAME = com.hbl.monitor-usb-sync.plist

.PHONY: all build clean install uninstall status logs

all: build

build:
	$(CC) $(SWIFT_FLAGS) $(SRC) -o $(TARGET)

clean:
	rm -f $(TARGET)

install: build
	mkdir -p $(SCRIPTS_DIR) $(INSTALL_BIN_DIR) $(LAUNCH_AGENTS_DIR)
	# Copy binaries and scripts
	cp $(TARGET) $(SCRIPTS_DIR)/$(TARGET)
	chmod +x $(SCRIPTS_DIR)/$(TARGET)
	cp bin/switch_monitor.sh $(SCRIPTS_DIR)/switch_monitor.sh
	chmod +x $(SCRIPTS_DIR)/switch_monitor.sh
	ln -sf $(SCRIPTS_DIR)/switch_monitor.sh $(INSTALL_BIN_DIR)/switch-monitor
	ln -sf $(SCRIPTS_DIR)/switch_monitor.sh $(INSTALL_BIN_DIR)/switch_monitor
	# Install LaunchAgent
	cp launchd/$(PLIST_NAME) $(LAUNCH_AGENTS_DIR)/$(PLIST_NAME)
	-launchctl unload $(LAUNCH_AGENTS_DIR)/$(PLIST_NAME) 2>/dev/null || true
	launchctl load $(LAUNCH_AGENTS_DIR)/$(PLIST_NAME)
	@echo "Installation complete and LaunchAgent service started."

uninstall:
	-launchctl unload $(LAUNCH_AGENTS_DIR)/$(PLIST_NAME) 2>/dev/null || true
	rm -f $(LAUNCH_AGENTS_DIR)/$(PLIST_NAME)
	rm -f $(SCRIPTS_DIR)/$(TARGET)
	rm -f $(INSTALL_BIN_DIR)/switch-monitor $(INSTALL_BIN_DIR)/switch_monitor
	@echo "Uninstalled service and binaries."

status:
	@launchctl list | grep monitor-usb-sync || echo "Service not running."

logs:
	@tail -f $(HOME)/monitor_usb_sync.log
