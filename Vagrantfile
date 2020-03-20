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
  config.vm.provision :shell, path: "init.sh", args: ENV['INIT_ARGS']
end
