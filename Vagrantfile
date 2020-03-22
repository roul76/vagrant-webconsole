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

  config.vm.provision "preparation"                 :shell, path: "prepare.sh",                     args: ENV['INIT_ARGS']
  config.vm.provision "start-webconsole-sshd"       :shell, path: "start-webconsole-sshd.sh",       args: ENV['INIT_ARGS']
  config.vm.provision "start-webconsole-nodestatic" :shell, path: "start-webconsole-nodestatic.sh", args: ENV['INIT_ARGS']
  config.vm.provision "start-webconsole-wetty"      :shell, path: "start-webconsole-wetty.sh",      args: ENV['INIT_ARGS']
  config.vm.provision "finalization"                :shell, path: "finalize.sh",                    args: ENV['INIT_ARGS']

#    config.vm.provision "step1", type: "ansible" do |ansible|
#      ansible.playbook = "playbook1.yml"
#      ansible.verbose = true
#    end
#
#    config.vm.provision "step2", type: "ansible" do |ansible|
#      ansible.playbook = "playbook2.yml"
#      ansible.verbose = true
#    end
end
