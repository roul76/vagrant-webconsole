Vagrant.configure(2) do |config|

  config.vm.define "webconsole" do |webconsole|
    webconsole.vm.box = "embedit/k8s"

    config.vm.provider "virtualbox" do |vbox|
      vbox.memory = 512
      vbox.cpus = 1
    end
  end

  config.vm.network "public_network", bridge: "en0: WLAN (AirPort)", mac: "080027000101"
  config.vm.provision :shell, path: "init.sh", args: ENV['INIT_ARGS']
end
