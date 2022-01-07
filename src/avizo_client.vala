using Gtk;

[DBus (name = "org.danb.avizo.service")]
interface AvizoService : GLib.Object
{
	public abstract string image_path { owned get; set; }
	public abstract string image_resource { owned get; set; }
	public abstract double progress { owned get; set; }
	public abstract int width { owned get; set; }
	public abstract int height { owned get; set; }
	public abstract int padding { owned get; set; }
	public abstract double y_offset { owned get; set; }
	public abstract int block_height { owned get; set; }
	public abstract int block_spacing { owned get; set; }
	public abstract int block_count { owned get; set; }
	public abstract Gdk.RGBA background { owned get; set; }
	public abstract Gdk.RGBA foreground { owned get; set; }

	public abstract void show(double seconds) throws DBusError, IOError;
}

public class AvizoClient : GLib.Application
{
	private static string VERSION = "1.0";

	private AvizoService _service = null;

	private static bool _show_version = false;
	private static bool _list_resources = false;
	private static string _image_base_dir = @"$(Environment.get_user_data_dir())/avizo";
	private static string _image_path = "";
	private static string _image_resource = "volume_muted";
	private static double _progress = 0.0;
	private static int _width = 248;
	private static int _height = 232;
	private static double _y_offset = 0.75;
	private static int _padding = 24;
	private static int _block_height = 10;
	private static int _block_spacing = 2;
	private static int _block_count = 20;
	private static string _foreground = "";
	private static string _background = "";

	private static double _time = 5.0;

	private const GLib.OptionEntry[] options = {
		{ "version", 0, 0, OptionArg.NONE, ref _show_version, "Display version number", null },
		{ "list-resources", 0, 0, OptionArg.NONE, ref _list_resources, "Lists the resource ids available", null },
		{ "image-base-dir", 0, 0, OptionArg.STRING, ref _image_base_dir, "The base directory to resolve relative image-path against (default is $XDG_DATA_HOME/avizo)", "PATH" },
		{ "image-path", 0, 0, OptionArg.STRING, ref _image_path, "Use the image specified by the path", "PATH" },
		{ "image-resource", 0, 0, OptionArg.STRING, ref _image_resource, "Use the image specified by the image resource id", "RESOURCE_ID" },
		{ "progress", 0, 0, OptionArg.DOUBLE, ref _progress, "Sets the progress in the notification, allowed values range from 0 to 1", "DOUBLE" },
		{ "width", 0, 0, OptionArg.INT, ref _width, "Sets the width of the notification", "INT" },
		{ "height", 0, 0, OptionArg.INT, ref _height, "Sets the height of the notification", "INT" },
		{ "y-offset", 0, 0, OptionArg.DOUBLE, ref _y_offset, "Sets relative offset of the notification to the top of the screen, allowed values range from 0 (top) to 1.0 (bottom)", "DOUBLE" },
		{ "padding", 0, 0, OptionArg.INT, ref _padding, "Sets the inner padding of the notification", "INT" },
		{ "block-height", 0, 0, OptionArg.INT, ref _block_height, "Sets the block height of the progress indicator", "INT" },
		{ "block-spacing", 0, 0, OptionArg.INT, ref _block_spacing, "Sets the spacing between blocks in the progress indicator", "INT" },
		{ "block-count", 0, 0, OptionArg.INT, ref _block_count, "Sets the amount of blocks in the progress indicator", "INT" },
		{ "background", 0, 0, OptionArg.STRING, ref _background, "Sets the background color in the format rgba([0, 255], [0, 255], [0, 255], [0, 1])", "STRING" },
		{ "foreground", 0, 0, OptionArg.STRING, ref _foreground, "Sets the foreground color in the format rgba([0, 255], [0, 255], [0, 255], [0, 1]), note that this does not affect the image", "STRING" },
		{ "time", 0, 0, OptionArg.DOUBLE, ref _time, "Sets the time to show the notification, default is 5", "DOUBLE" },
		{ null }
	};

	public AvizoClient()
	{
		Object(application_id: "org.danb.avizo.client",
		       flags: ApplicationFlags.HANDLES_COMMAND_LINE);

		_service = Bus.get_proxy_sync(BusType.SESSION, "org.danb.avizo.service",
		                                             "/org/danb/avizo/service");
	}

	public override int command_line(ApplicationCommandLine command_line)
	{
		try
		{
			load_config();
		}
		catch (Error e)
		{
			if (!(e is KeyFileError.NOT_FOUND))
			{
				stderr.printf(@"avizo: Failed to load configuration file: $(e.message)\n");
				return 1;
			}
		}

		// this is an ugly workaround to deal with args being owned
		string[] args = command_line.get_arguments();
		string[] _args = new string[args.length];
		unowned string[] tmp = _args;
		for (int i = 0; i < args.length; i++)
		{
			_args[i] = args[i];
		}

		try
		{
			var opt_context = new OptionContext("- Run avizo-client");
			opt_context.set_help_enabled(true);
			opt_context.add_main_entries(options, null);

			opt_context.parse(ref tmp);
		}
		catch (OptionError e)
		{
			stderr.printf(@"avizo: $(e.message)\n");
			stderr.printf(@"Run '$(args[0]) --help' to see a full list of available command line options.\n");

			return 1;
		}

		if (_show_version)
		{
			print(@"noti-client $VERSION)\n");

			return 0;
		}

		if (_list_resources)
		{
			print("Available resources:\n");
			print("  volume_muted\n");
			print("  volume_low\n");
			print("  volume_medium\n");
			print("  volume_high\n");
			print("  mic_muted\n");
			print("  mic_unmuted\n");
			print("  brightness_low\n");
			print("  brightness_medium\n");
			print("  brightness_high\n");

			return 0;
		}

		if (_image_path != "")
		{
			_service.image_path = Filename.canonicalize(_image_path, _image_base_dir);
		}
		else
		{
			_service.image_resource = _image_resource;
		}

		_service.progress = _progress;
		_service.width = _width;
		_service.height = _height;
		_service.padding = _padding;
		_service.y_offset = _y_offset;
		_service.block_height = _block_height;
		_service.block_spacing = _block_spacing;
		_service.block_count = _block_count;

		if (_background != "")
		{
			Gdk.RGBA bg = Gdk.RGBA();
			bg.parse(_background);

			_service.background = bg;
		}

		if (_foreground != "")
		{
			Gdk.RGBA fg = Gdk.RGBA();
			fg.parse(_foreground);

			_service.foreground = fg;
		}

		_service.show(_time);

		return 0;
	}

	private void load_config() throws KeyFileError, FileError
	{
		string[] search_dirs = {};
		search_dirs += Environment.get_user_config_dir();
		foreach (var dir in Environment.get_system_config_dirs())
		{
			search_dirs += dir;
		}

		string config_path;
		var conf = new KeyFile();
		conf.load_from_dirs("avizo/config.ini", search_dirs, out config_path, KeyFileFlags.NONE);

		debug("Loading configuration from %s", config_path);

		var group = conf.get_start_group();

		// Copy key values from the config file into static variables of this class
		// (e.g. `_width`) according to the mapping specified in the options array.
		foreach (var entry in options)
		{
			if (entry.long_name == null || !conf.has_key(group, entry.long_name))
			{
				continue;
			}
			switch (entry.arg)
			{
				case OptionArg.DOUBLE:
					*((double*) entry.arg_data) = conf.get_double(group, entry.long_name);
					break;
				case OptionArg.INT:
					*((int*) entry.arg_data) = conf.get_integer(group, entry.long_name);
					break;
				case OptionArg.STRING:
					var value = conf.get_string(group, entry.long_name);
					*((void**) entry.arg_data) = (owned) value;
					break;
				default:
					break;
			}
		}
	}
}

public void main(string[] args)
{
	AvizoClient client = new AvizoClient();
	client.run(args);
}
