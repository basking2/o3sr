# frozen_string_literal: true

require "yaml"

module O3sr
  # Config helpers for loading YAML config using XDG Base Directory spec
  module Config
    module_function

    def xdg_config_home
      if ENV.key?("XDG_CONFIG_HOME") && !ENV["XDG_CONFIG_HOME"].to_s.empty?
        ENV["XDG_CONFIG_HOME"]
      else
        File.join(Dir.home, ".config")
      end
    end

    def xdg_path
      File.join(xdg_config_home, "o3sr", "config.yml")
    end

    def legacy_path
      File.expand_path("~/.o3sr.yml")
    end

    # Return the path to use (XDG first, then legacy), or nil if none exist
    def config_path
      return xdg_path if File.exist?(xdg_path)
      return legacy_path if File.exist?(legacy_path)
      nil
    end

    # Load the config file and return a Hash with symbolized keys.
    # Returns empty hash if nothing to load or on error.
    def load_config
      cp = config_path
      return {} unless cp

      begin
        conf = YAML.load_file(cp) || {}
        unless conf.is_a?(Hash)
          warn "Warning: config file #{cp} ignored: must contain a mapping"
          return {}
        end
        if cp == legacy_path && cp != xdg_path
          warn "Warning: using legacy config #{cp}; consider moving to #{xdg_path}"
        end
        conf.each_with_object({}) { |(k, v), h| h[k.to_sym] = v }
      rescue StandardError => e
        warn "Warning: failed to read config #{cp}: #{e.message}"
        {}
      end
    end
  end
end
