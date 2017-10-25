# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.

# Zip Package creation requires PowerShell v3 or above and .NET 4.5 or above.

# SMB credentials are those for the user executing vagrant commands, if domain user, use @ format
# [Environment]::SetEnvironmentVariable('VAGRANT_SMB_USER', 'username', 'User')
# [Environment]::SetEnvironmentVariable('VAGRANT_SMB_PASS', 'p4ssWord!', 'User')

Vagrant.configure(2) do |allhosts|

  allhosts.vm.define 'target' do |target|
    target.vm.box = 'cdaf/WindowsServerStandard'
    target.vm.communicator = 'winrm'
    target.vm.boot_timeout = 600
    target.winrm.timeout =   1800 # 30 minutes
    target.winrm.retry_limit = 10
    target.winrm.username = "vagrant" # Making defaults explicit
    target.winrm.password = "vagrant" # Making defaults explicit
    target.vm.graceful_halt_timeout = 180 # 3 minutes
    # Oracle VirtualBox, relaxed configuration for Desktop environment
    target.vm.provision 'shell', path: './automation/provisioning/mkdir.ps1', args: 'C:\deploy'
    target.vm.provision 'shell', path: './automation/remote/capabilities.ps1'
    target.vm.provider 'virtualbox' do |virtualbox, override|
      virtualbox.gui = false
      override.vm.network 'private_network', ip: '172.16.17.103'
      override.vm.network 'forwarded_port', guest: 3389, host: 33389, auto_correct: true # Remote Desktop
      override.vm.network 'forwarded_port', guest: 5985, host: 35985, auto_correct: true # WinRM HTTP
      override.vm.network 'forwarded_port', guest: 5986, host: 33986, auto_correct: true # WinRM HTTPS
      override.vm.network 'forwarded_port', guest:   80, host: 30080, auto_correct: true
      override.vm.network 'forwarded_port', guest:  443, host: 30443, auto_correct: true
      override.vm.provision 'shell', path: './automation/provisioning/CredSSP.ps1', args: 'client'
      override.vm.provision 'shell', path: './automation/provisioning/CredSSP.ps1', args: 'server'
    end
    # Microsoft Hyper-V does not support NAT or setting hostname. vagrant up app --provider hyperv
    target.vm.provider 'hyperv' do |hyperv, override|
      hyperv.ip_address_timeout = 300 # 5 minutes, default is 2 minutes (120 seconds)
      override.vm.synced_folder ".", "/vagrant", type: "smb", smb_username: "#{ENV['VAGRANT_SMB_USER']}", smb_password: "#{ENV['VAGRANT_SMB_PASS']}"
      override.vm.provision 'shell', path: './automation/provisioning/removeUser.ps1', args: 'vagrant'
    end
  end

  allhosts.vm.define 'buildserver' do |buildserver|
    buildserver.vm.box = 'cdaf/WindowsServerStandard'
    buildserver.vm.communicator = 'winrm'
    buildserver.vm.boot_timeout = 600
    buildserver.winrm.timeout =   1800 # 30 minutes
    buildserver.winrm.retry_limit = 10
    buildserver.winrm.username = "vagrant" # Making defaults explicit
    buildserver.winrm.password = "vagrant" # Making defaults explicit
    buildserver.vm.graceful_halt_timeout = 180 # 3 minutes
    buildserver.vm.provision 'shell', path: './automation/remote/capabilities.ps1'
    # Oracle VirtualBox, relaxed configuration for Desktop environment
    buildserver.vm.provider 'virtualbox' do |virtualbox, override|
      virtualbox.gui = false
      override.vm.network 'private_network', ip: '172.16.17.101'
      override.vm.network 'forwarded_port', guest: 3389, host: 13389, auto_correct: true # Remote Desktop
      override.vm.network 'forwarded_port', guest: 5985, host: 15985, auto_correct: true # WinRM HTTP
      override.vm.network 'forwarded_port', guest: 5986, host: 15986, auto_correct: true # WinRM HTTPS
      override.vm.provision 'shell', path: './automation/provisioning/addHOSTS.ps1', args: '172.16.17.103 target.sky.net'
      override.vm.provision 'shell', path: './automation/provisioning/trustedHosts.ps1', args: '*'
      override.vm.provision 'shell', path: './automation/provisioning/CredSSP.ps1', args: 'client'
      override.vm.provision 'shell', path: './automation/provisioning/CredSSP.ps1', args: 'server'
      override.vm.provision 'shell', path: './automation/provisioning/setenv.ps1', args: 'interactive yes User'
      override.vm.provision 'shell', path: './automation/provisioning/setenv.ps1', args: 'environmentDelivery VAGRANT Machine'
      override.vm.provision 'shell', path: './automation/provisioning/CDAF_Desktop_Certificate.ps1'
      override.vm.provision 'shell', path: './automation/provisioning/CDAF.ps1'
    end
    buildserver.vm.provider 'hyperv' do |hyperv, override|
      hyperv.ip_address_timeout = 300 # 5 minutes, default is 2 minutes (120 seconds)
      override.vm.synced_folder ".", "/vagrant", type: "smb", smb_username: "#{ENV['VAGRANT_SMB_USER']}", smb_password: "#{ENV['VAGRANT_SMB_PASS']}"
      override.vm.provision 'shell', path: './automation/provisioning/removeUser.ps1', args: 'vagrant'
    end
  end

end