# Configuration management.
module Golem::Config
    # List of paths config file is searched for.
    CFG_PATHS = ["/usr/local/etc/golem.conf.rb", "/etc/golem.conf.rb", "~/golem.conf.rb"]
    # List of available config variable names.
    CFG_VARS = [:db, :user_home, :repository_dir, :cfg_path, :base_dir, :bin_dir, :hooks_dir]

    # Auto configure Golem. Tries to find config file, if one can be found executes it, otherwise calls {configure}.
    # @param [String] path path to config file.
    def self.auto_configure(path = nil)
	path = if ENV.key?('GOLEM_CONFIG') && File.exists?(ENV['GOLEM_CONFIG'])
	    ENV['GOLEM_CONFIG']
	elsif ENV.key?('GOLEM_BASE') && File.exists?(ENV['GOLEM_BASE'] + "/golem.conf.rb")
	    ENV['GOLEM_BASE'].to_s + "/golem.conf.rb"
	else
	    CFG_PATHS.find {|try_path| File.exists?(try_path)}
	end unless File.exists?(path)
	if File.exists?(path)
	    require path
	    self.cfg_path = path
	    self
	else
	    configure path
	end
    end

    # Configure Golem with options given as argument, yield self then setting defaults.
    # @overload configure(path, &block)
    #   @param [String] path path to config file (interpreted as <i>:cfg_path => path</i>).
    # @overload configure(opts, &block)
    #   @param [Hash] opts options or single path .
    #   @option opts [String] :db db configuration (postgres url or 'static'),
    #   @option opts [String] :user_home path to user's home directory (needed to place .ssh/authorized_keys), defaults to ENV['HOME'],
    #   @option opts [String] :repository_dir path to repositories, may be relative to +user_home+,
    #   @option opts [String] :cfg_path path config file, defaults to +base_dir+ + '/golem.conf.rb' if not set,
    #   @option opts [String] :base_dir path to base, defaults to in order ENV['GOLEM_BASE'], basedir of config file (if exists), basedir of library,
    #   @option opts [String] :bin_dir path to directory containing the executable, defaults to +base_dir+ + '/bin' if not set,
    #   @option opts [String] :hooks_dir path to directory containing hooks, defaults to +base_dir+ + '/hooks' if not set.
    # @return [Config] self.
    def self.configure(opts_or_path = nil, &block)
	opts = opts_or_path.is_a?(Hash) ? opts_or_path : {:cfg_path => opts_or_path}
	@vars = opts.reject {|k, v| ! CFG_VARS.include?(k)}
	yield self if block_given?
	self.user_home = ENV['HOME'] if user_home.nil? && ENV.key?('HOME')
	self.repository_dir = user_home + "/repositories" unless repository_dir
	unless base_dir
	    self.base_dir = if ENV.key?('GOLEM_BASE')
		ENV['GOLEM_BASE']
	    elsif File.exists?(cfg_path.to_s)
		File.dirname(cfg_path.to_s)
	    else
		File.expand_path(File.dirname(__FILE__) + '/../..')
	    end
	end
	self.cfg_path = base_dir + '/golem.conf.rb' unless cfg_path
	self.bin_dir = base_dir + '/bin' unless bin_dir
	self.hooks_dir = base_dir + '/hooks' unless hooks_dir
	self
    end

    # Override +respond_to?+ to respond to +.config_var+ and +.config_var=+ (e.g. Golem::Config.db = 'static').
    def self.respond_to?(sym)
	CFG_VARS.include?(sym) || (sym.to_s.match(/=\z/) && CFG_VARS.include?(sym.to_s[0..-2].to_sym)) || super
    end

    # Override +method_missing+ to handle +.config_var+ and +.config_var=+ (e.g. Golem::Config.db = 'static').
    def self.method_missing(sym, *args, &block)
	auto_configure unless @vars
	return @vars[sym] if CFG_VARS.include?(sym)
	return @vars[sym.to_s[0..-2].to_sym] = args.first if sym.to_s.match(/=\z/) && CFG_VARS.include?(sym.to_s[0..-2].to_sym)
	super
    end

    # Get configuration variables that is set (e.g. not +nil+).
    # @return [Hash] configuration variables.
    def self.config_hash
	auto_configure unless @vars
	@vars.reject {|k, v| v.nil?}
    end

    # Write configuration to file.
    def self.save!
	abort "No configuration path given!" unless cfg_path
	File.open(cfg_path, 'w') {|f| f.write("Golem.configure do |cfg|\n" + config_hash.collect {|k, v| "\tcfg.#{k.to_s} = \"#{v.to_s}\""}.join("\n") + "\nend\n")}
    end

    # @return [String] path to +authorized_keys+ file.
    def self.keys_file_path
	user_home + "/.ssh/authorized_keys"
    end

    # @return [String] path to directory containing repositories.
    def self.repository_base_path
	(repository_dir[0..0] == "/" ? '' : user_home + '/') + repository_dir
    end

    # @param [String] repo repository name.
    # @return [String] path to given repository.
    def self.repository_path(repo)
	repository_base_path + '/' + repo.to_s + '.git'
    end

    # @param [String] hook hook name.
    # @return [String] path to given hook.
    def self.hook_path(hook)
	hooks_dir + "/" + hook.to_s
    end
end
