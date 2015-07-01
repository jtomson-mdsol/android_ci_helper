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
        shell_out "#{ADB_CMD} #{cmd}"
    end

    def self.list_installed_emulators(version: nil, abi: "armeabi-v7a")
        list_avd = `#{ANDROID_CMD} list avd`
        names = []
        list_avd.split("\n").grep(/Name:/).each { |name|
            names << name.strip().split()[1]
        }
        targets = []
        list_avd.split("\n").grep(/Target:/).each { |target|
            targets << target.strip().split(":")[1]
        }
        abis = []
        list_avd.split("\n").grep(/Tag\/ABI:/).each { |tagAbi|
            abis << tagAbi.strip().split(":")[1]
        }
        if version
            tmp = []
            for i in 0..(targets.length-1)
                tmp << names[i] if (targets[i].include?(version)) && (abi.nil? || abis[i].include?(abi))
            end
            names = tmp
        end
        names
    end

    # list device connected name such as emulator-5554
    def self.list_connected_emulators
        output = `#{ADB_CMD} devices`.split("\n")
        return [] unless output.count > 1

        # first line is "List of devices attached"
        emulators = output.drop(1).map { |line| line.split("\t").first }
        return emulators
    end

    # list device actual name such as android-avd-21
    def self.list_running_emulators
        devices = []
        # both linux and darwin provide command ps but they behavior differently
        # by default. On linux, it only shows processes under the same terminal
        # while on darwin, it shows processes under the same user id with the
        # caller. On linux, we use param: aux to show all process belonging to
        # the caller.
        ps_cmd = "ps -aux"
        host_os = RbConfig::CONFIG['host_os']
        ps_cmd = "ps" if host_os.include?("darwin") || host_os.include?("mac os")
        ps = `#{ps_cmd}`

        ps.split("\n").grep(/emulator/).each do |t|
            avd_token_found = false
            t.split(" ").each do |t2|
                if avd_token_found
                    devices << t2
                    break
                end
                avd_token_found = true if t2=="-avd"
            end
        end
        return devices
    end

    def self.adb_prop_eq?(prop, expected)
        cmd = "#{ADB_CMD} shell getprop #{prop}"
        ret = %x[#{cmd} 2>&1].strip
        puts "--- 'getprop #{prop}' returned '#{ret}'"
        ret == expected
    end

    def self.emulator_ready?
        adb_prop_eq?("dev.bootcomplete",       "1")       or return false
        adb_prop_eq?("sys.boot_completed",     "1")       or return false

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

    # For most of the junit-tests, we don't need skip to pass the tests.
    # However, without skin, the functional tests cannot properly locate the UI
    # element and the tests will fail.
    def self.start_and_wait_for_ready(emulator_name, no_skin:true)
        puts "--- starting emulator #{emulator_name}..."

        $emulator_pid = fork {
            additional_params = ''
            additional_params += "-no-skin" if no_skin
            puts `#{EMULATOR_CMD} -avd #{emulator_name}-no-audio -no-window -wipe-data #{additional_params}`
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
        # change to 30 because on my dev machine it might take up to 27 tries before success
        1.upto(30) do |attempt|
            puts "--- attempt ##{attempt}"
            break if emulator_ready?
            puts "--- waiting 10 seconds before next attempt"
            sleep 10
        end

        unless emulator_ready?
            puts "******** error starting #{emulator_name} - timed out waiting for ready ********"
            return false
        end

        puts "--- emulator #{emulator_name} is ready"
        return true
    end

end # end module AndroidCIHelper
