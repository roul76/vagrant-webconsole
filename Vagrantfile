Vagrant.configure(2) do |config|

  config.vm.define "webconsole" do |webconsole|
    webconsole.vm.box = "embedit/k8s"

    config.vm.provider "virtualbox" do |vbox|
      vbox.memory = 640
      vbox.cpus = 1
    end
  end

  # MacBook: export VAGRANT_BRIDGE_NETWORK_ADAPTER="en0: WLAN (AirPort)"
  # others:  export VAGRANT_BRIDGE_NETWORK_ADAPTER="enp1s0"
  config.vm.network "public_network", bridge: ENV['VAGRANT_BRIDGE_NETWORK_ADAPTER'], mac: "080027000101"

  config.vm.provision "preparation", type: "shell" do |shell|
    shell.path = "prepare.sh"
    shell.args = ENV['INIT_ARGS']
  end

  config.vm.provision "start-webconsole-sshd", type: "shell" do |shell|
    shell.path = "start-webconsole-sshd.sh"
    shell.args = ENV['INIT_ARGS']
  end

  config.vm.provision "start-webconsole-nodestatic", type: "shell" do |shell|
    shell.path = "start-webconsole-nodestatic.sh"
    shell.args = ENV['INIT_ARGS']
  end

  config.vm.provision "start-webconsole-wetty", type: "shell" do |shell|
    shell.path = "start-webconsole-wetty.sh"
    shell.args = ENV['INIT_ARGS']
  end

  config.vm.provision "finalization", type: "shell" do |shell|
    shell.path = "finalize.sh"
    shell.args = ENV['INIT_ARGS']
  end

end
