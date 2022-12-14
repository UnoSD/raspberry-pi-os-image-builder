variable "image_url"            { type = string }
variable "image_checksum"       { type = string }
variable "ssh_public_key_path"  { type = string }
variable "openvpn_file_path"    { type = string }
variable "username"             { type = string }
variable "hostname"             { type = string }
variable "timezone"             { type = string }
variable "workspace_id"         { type = string }
variable "storage_account_name" { type = string }
variable "storage_username"     { type = string }

variable "motion_password" {
    type      = string
    sensitive = true
}

variable "exclude_plugins" {
    type    = string
    default = "none"
}

variable "workspace_key" {
    type      = string
    sensitive = true
}

variable "network" {
    type    = object({
        ip      = string
        subnet  = string
        gateway = string
    })
    default = null
}

variable "wpa_supplicant_path" {
    type    = string 
    default = ""
}

packer {
    required_plugins {
        arm-image = {
            version = ">= 0.2.5"
            source  = "github.com/solo-io/arm-image"
        }
    }
}

source "arm-image" "raspbian" {
    iso_url           = "${var.image_url}"
    iso_checksum      = "${var.image_checksum}"
    target_image_size = 4294967296
}

build {
    sources = [ "source.arm-image.raspbian" ]

    provisioner "file" {
        source      = "plugins"
        destination = "/tmp"
    }
    
    provisioner "file" {
        source      = "${var.openvpn_file_path}"
        destination = "/tmp/azure.conf"
    }

    provisioner "shell" {
        environment_vars = [ 
            "USERNAME=${var.username}",
            "IP=${var.network.ip}",
            "SUBNET=${var.network.subnet}",
            "GATEWAY=${var.network.gateway}",
            "HOSTNAME=${var.hostname}",
            "WORKSPACE_ID=${var.workspace_id}",
            "WORKSPACE_KEY=${var.workspace_key}",
            "TIMEZONE=${var.timezone}",
            "EXCLUDE_PLUGINS=${var.exclude_plugins}",
            "MOTION_PASSWORD=${var.motion_password}",
            "STORAGE_ACCOUNT_NAME=${var.storage_account_name}",
            "STORAGE_USERNAME=${var.storage_username}"
        ]
        script = "./setup.sh"
    }

    provisioner "file" {
        source      = "${var.ssh_public_key_path}"
        destination = "/home/${var.username}/.ssh/authorized_keys"
    }

    provisioner "file" {
        source      = "id_rsa"
        destination = "/etc/ssh/ssh_motion"
    }
    
    provisioner "file" {
        source      = "${var.wpa_supplicant_path}"
        destination = "/etc/wpa_supplicant/wpa_supplicant.conf"
    }
    
    provisioner "shell" {
        inline = [ "chown ${var.username}:${var.username} /home/${var.username}/.ssh/authorized_keys" ]
    }
}