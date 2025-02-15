terraform {
  required_providers {
    # https://registry.terraform.io/providers/terraform-lxd/lxd/latest
    lxd = {
      source = "terraform-lxd/lxd"
      version = "2.4.0"
    }
  }
}

provider "lxd" {
  generate_client_certificates = true
  accept_remote_certificate = true
}

resource "lxd_profile" "profile" {
  name = "zh_ansible"
  description = "ZuperHunt Ansible testing on LXD"

  config = {
    "security.secureboot" = false
  }
}

resource "lxd_volume" "vol" {
  count = var.instance_count
  name = "zh_ansible_vol_${count.index}"
  pool = "default"
  config = {
    "size" = "20GiB"
  }
}

resource "lxd_instance" "container" {
  count = var.instance_count
  name = "zh-ansible-${count.index}"
  image = "ubuntu:24.04"
  type = "virtual-machine"
  profiles = ["default", "${lxd_profile.profile.name}"]

  execs = {
    "00-create-user" = {
      command = ["useradd", "-m", "ubuntu"]
      trigger = "on_start"
    }
    "01-delete-password" = {
      command = ["passwd", "-d", "ubuntu"]
      trigger = "on_start"
    }
  }

  device {
    name = "zh_ansible_vol_${count.index}"
    type = "disk"
    properties = {
      path = "/srv/zh_ansible_vol"
      source = "${lxd_volume.vol[count.index].name}"
      pool = "${lxd_volume.vol[count.index].pool}"
    }
  }
}

resource "lxd_instance_file" "ssh" {
  count = var.instance_count
  instance = lxd_instance.container[count.index].name
  source_path = "${var.ssh_public_key_path}"
  target_path = "/home/ubuntu/.ssh/authorized_keys"
  create_directories = true
  mode = 0600
  uid = 1000
  gid = 1000
}

output "lxd_instance_ipv4" {
  value = lxd_instance.container.*.ipv4_address
}

