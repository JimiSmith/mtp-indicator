
using Gtk; 
using AppIndicator;
using UDev;
using Gee;

extern bool is_directory_mounted(string directory);

public class AndroidDevice {
    public string name;
    public string mount_dir;
	private Gtk.MenuItem menu_item;

    public AndroidDevice(string name) {
        this.name = name;
        this.mount_dir = string.join("/", GLib.Environment.get_variable("HOME"), this.name);
    }

    public void mount() {
        File file = File.new_for_path(this.mount_dir);
        try {
            file.make_directory_with_parents();
        } catch (Error e) {
            stdout.printf ("Error: %s\n", e.message);
        }
        GLib.Pid child_pid;
            try {
            GLib.Process.spawn_async(GLib.Environment.get_variable("HOME"), {"go-mtpfs", this.mount_dir}, Environ.get(),
                SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD, null, out child_pid);
            ChildWatch.add (child_pid, (pid, status) => {
                // Triggered when the child indicated by child_pid exits
                Process.close_pid (pid);
            });
        } catch (Error e) {
            stdout.printf ("Error: %s\n", e.message);
        }
    }

    public void unmount() {
        GLib.Pid child_pid;
            try {
            GLib.Process.spawn_async(GLib.Environment.get_variable("HOME"), {"fusermount", "-u", this.mount_dir}, Environ.get(),
                SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD, null, out child_pid);
            ChildWatch.add (child_pid, (pid, status) => {
                // Triggered when the child indicated by child_pid exits
                Process.close_pid (pid);
            });
        } catch (Error e) {
            stdout.printf ("Error: %s\n", e.message);
        }
    }

    public bool is_mounted() {
        return is_directory_mounted(this.mount_dir);
    }

	public Gtk.MenuItem get_menu_item() {
		if (this.menu_item != null) {
			return this.menu_item;
		}
        var prefixed_label = "";
        if (this.is_mounted()) {
            prefixed_label = "Unmount " + this.name;
        } else {
            prefixed_label = "Mount " + this.name;
        }

        this.menu_item = new Gtk.MenuItem.with_label(prefixed_label);
        this.menu_item.show();
        this.menu_item.activate.connect(() => {
			string new_label = "";
            if (this.is_mounted()) {
                this.unmount();
                new_label = "Mount " + this.name;
            } else {
                this.mount();
                new_label = "Unmount " + this.name;
            }
            this.menu_item.set_label(new_label);
        });
		return this.menu_item;
	}
}

public class AndroidMTPIndicator {
    private Gtk.Menu menu;
    private UDev.Context context;
	private HashMap<string, AndroidDevice> device_map;
    
    public AndroidMTPIndicator(string[] args) {
        Gtk.init(ref args);
        var indicator = new Indicator("android-mtp-indicator", "indicator-messages",
          IndicatorCategory.APPLICATION_STATUS);
        indicator.set_icon_theme_path("/usr/local/share/android-mtp-indicator/icons/16x16");
        indicator.set_status (IndicatorStatus.ACTIVE);
        indicator.set_icon ("indicator-robot");

        this.menu = new Gtk.Menu();

		this.device_map = new HashMap<string, AndroidDevice>();

        indicator.set_menu(this.menu);

        populate();

		monitor();

        var quit_item = new Gtk.MenuItem.with_label("Quit");
        quit_item.show();
        quit_item.activate.connect(() => {
			  Gtk.main_quit();
		});
        this.menu.append(quit_item);
		
        Gtk.main();
    }

	private void add_device(UDev.Device dev) {
		AndroidDevice device = new AndroidDevice(name_for_device(dev));
		this.device_map[dev.syspath] = device;
        this.menu.prepend(device.get_menu_item());
	}

	private void remove_device(UDev.Device dev) {
		AndroidDevice device = get_device(dev);
		if (device == null) return;
		if (dev.syspath in this.device_map) {
			this.device_map.unset(dev.syspath);
		}
		menu.remove(device.get_menu_item());
	}

	private AndroidDevice? get_device(UDev.Device dev) {
		if (dev.syspath in this.device_map) {
			return this.device_map[dev.syspath];
		}
		return null;
	}

    private void populate() {
        context = new UDev.Context();
        var e = context.create_enumerate();
        e.add_match_subsystem("usb");
        e.scan_devices();
        for(unowned UDev.List d = e.entries; d != null; d = d.next) {
            var path = d.name;
            var dev = context.open_syspath(path);
            if(dev.properties.get("ID_MTP_DEVICE").value == "1") { // we have an MTP device
				this.add_device(dev);
            }
        }
    }
    
    private void monitor() {
        var m = context.monitor_from_netlink();
        m.add_match_subsystem_devtype("usb");
        m.add_match_subsystem_devtype("bdi");
        m.enable_receiving();

		// create a new channel to monitor the UDev monitor file descriptor
		GLib.IOChannel channel = new GLib.IOChannel.unix_new(m.fd);
		// create a new IOSource to attach to the main event loop
		GLib.IOSource source = new GLib.IOSource(channel, GLib.IOCondition.IN);
		// will be called when something is available to read from the monitor file descriptor
		source.set_callback ((s, cond) => {
					var dev = m.receive_device();
					if (dev != null) { // we have an MTP device
						if (dev.subsystem == "usb") {
							if (dev.properties.get("ID_MTP_DEVICE").value != "1") {
								return true;
							}
							GLib.message("device event received: %s, %s", dev.subsystem, dev.devtype);
							if (dev.action == "add") {
								this.add_device(dev);
							} else if (dev.action == "remove") {
								this.remove_device(dev);
							}
						} else {
							GLib.message("mount event received: %s", dev.subsystem);
						}
					} else {
						GLib.warning("No device received");
					}
					return true;
        });
		// attach to main context
		source.attach(null);
    }

	private string name_for_device(UDev.Device dev) {
		return dev.properties.get("ID_VENDOR_ENC").value
		+ " " + dev.properties.get("ID_MODEL_ENC").value
		+ " (" + dev.properties.get("ID_SERIAL_SHORT").value + ")";
	}
}

public static int main(string[] args) {
    new AndroidMTPIndicator(args);

    return 0;
}