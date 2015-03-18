require "android_ci_helper/version"

module AndroidCIHelper

    ANDROID_HOME = ENV['ANDROID_HOME'] || raise("Error: must set $ANDROID_HOME environment variable")
    
    ADB_CMD = File.join(ANDROID_HOME, 'platform-tools', 'adb')
    EMULATOR_CMD = File.join(ANDROID_HOME, 'tools', 'emulator')
    ANDROID_CMD = File.join(ANDROID_HOME, 'tools', 'android')

    $emulator_pid = 0

    def self.shell_out(cmd)
        puts "--- calling: #{cmd}"
        puts %x[#{cmd} 2>&1].strip
        success = $?.success?
        success or puts "--- command returned non-zero status: #{$?.to_i}"
        return success
    end

    def self.adb_cmd(cmd)
        return shell_out "#{ADB_CMD} #{cmd}"
    end

    def self.list_installed_emulators
        # collect array like ["Name: <emu-name> ", "Name: <another-emu-name>"]
        name_output = `#{ANDROID_CMD} list avd`.split("\n").grep(/Name:/)

        names = []
        name_output.each { |name|
            names << name.strip().split()[1]
        }

        return names
    end

    def self.list_connected_emulators
        output = `#{ADB_CMD} devices`.split("\n")
        return [] unless output.count > 1

        emulators = []
        # first line is "List of devices attached"
        output.drop(1).each { |line|
            emulators << line.split("\t")[0]
        }
        return emulators
    end

    def self.adb_prop_eq?(prop, expected)
        cmd = "#{ADB_CMD} shell getprop #{prop}"
        ret = %x[#{cmd} 2>&1].strip
        puts "--- 'getprop #{prop}' returned '#{ret}'"
        ret == expected
    end

    def self.emulator_ready?
        adb_prop_eq?("dev.bootcomplete",      "1") or return false
        adb_prop_eq?("sys.boot_completed",    "1") or return false
        (adb_prop_eq?("service.bootanim.exit", "1") || 
            adb_prop_eq?("init.svc.bootanim", "stopped")) or return false
        return true
    end


    def self.kill_existing_emulator_sessions
        puts "--- stopping any running emulators"
        shell_out "pkill -9 emulator*"

        puts "--- restarting adb server"
        adb_cmd "kill-server"
        adb_cmd "start-server"
    end

    def self.start_and_wait_for_ready(emulator_name)
        puts "--- starting emulator #{emulator_name}..."
        
        $emulator_pid = fork {
            puts `#{EMULATOR_CMD} -avd #{emulator_name} -no-skin -no-audio -no-window -wipe-data`
        }

        puts "--- checking emulator pid: #{$emulator_pid}"
        sleep 5

        begin
            Process.getpgid $emulator_pid
        rescue
            puts "******** error starting #{emulator_name} ********"
            return false
        end

        puts "--- emulator process is alive"

        # wait for ready
        attempts = 1
        while attempts <= 20 do
            puts "--- attempt # #{attempts}"
            break if emulator_ready?
            puts "--- waiting 10 seconds before next attempt"
            attempts += 1
            sleep 10
        end

        if (attempts > 20)
            puts "******** error starting #{emulator_name} - timed out waiting for ready ********"
            return false
        end
        
        puts "--- emulator #{emulator_name} is ready"
        return true
    end

end # end module AndroidCIHelper
