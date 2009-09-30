module Babushka
  class BaseDepRunner < DepRunner

    delegate :pkg_manager, :to => :definer

    private

    # This probably should be elsewhere, because it only works on DepRunners that
    # define #provides.
    def cmds_in_path? commands = provides, custom_cmd_dir = nil
      present, missing = commands.partition {|cmd_name| cmd_dir(cmd_name) }
      good, bad = if custom_cmd_dir
        present.partition {|cmd_name| cmd_dir(cmd_name) == custom_cmd_dir }
      else
        present.partition {|cmd_name| pkg_manager.cmd_in_path? cmd_name }
      end

      log_ok "#{good.map {|i| "'#{i}'" }.to_list} run#{'s' if good.length == 1} from #{cmd_dir(good.first)}." unless good.empty?
      log_error "#{missing.map {|i| "'#{i}'" }.to_list} #{missing.length == 1 ? 'is' : 'are'} missing from your PATH." unless missing.empty?

      unless bad.empty?
        path_error = "#{bad.map {|i| "'#{i}'" }.to_list} incorrectly run#{'s' if bad.length == 1} from #{cmd_dir(bad.first)}."
        unless /#{pkg_manager.bin_path}.*#{cmd_dir(bad.first)}/ =~ ENV['PATH']
          log_error path_error
          # The incorrect paths were caused by path order, not just binaries missing from the correct path.
          unless pkg_manager == Babushka::BaseHelper
            # Don't recommend putting the system path ahead of manager-specific paths.
            log "You need to put #{pkg_manager.bin_path} before #{cmd_dir(bad.first)} in your PATH."
          end
          :fail
        else
          log path_error
        end
      else
        missing.empty?
      end
    end

    def dmg url, &block
      download url
      output = shell "hdiutil attach #{File.basename url}"
      unless output.nil?
        path = output.val_for(/^\/dev\/disk\d+s\d+\s+Apple_HFS\s+/)
        returning yield path do
          shell "hdiutil detach #{path}"
        end
      end
    end

    def source url, &block
      in_build_dir {
        output = get_source url
        unless output.nil?
          in_build_dir output do |path|
            yield path
          end
        end
      }
    end

    def git url, &block
      in_build_dir {
        shell "git clone #{url}" and
        in_build_dir(File.basename(url)) {|path|
          yield path
        }
      }
    end

  end
end
