variable "image_url"           { type = string }
variable "image_checksum"      { type = string }
variable "ssh_public_key_path" { type = string }
variable "openvpn_file_path"   { type = string }
variable "username"            { type = string }
variable "hostname"            { type = string }
variable "timezone"            { type = string }
variable "workspace_id"        { type = string }

variable "workspace_key" {
    type = string
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

source "arm-image" "raspbian" {
    iso_url      = "${var.image_url}"
    iso_checksum = "${var.image_checksum}"
}

build {
    sources = [ "source.arm-image.raspbian" ]

    provisioner "file" {
        source      = "${var.openvpn_file_path}"
        destination = "/etc/openvpn/client/azure.conf"
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
            "TIMEZONE=${var.timezone}"
        ]
        script = "./setup.sh"
    }

    provisioner "file" {
        source      = "${var.ssh_public_key_path}"
        destination = "/home/${var.username}/.ssh/authorized_keys"
    }

    provisioner "file" {
        source      = "${var.wpa_supplicant_path}"
        destination = "/etc/wpa_supplicant/wpa_supplicant.conf"
    }
    
    provisioner "file" {
        source      = "fluent-bit.conf"
        destination = "/etc/fluent-bit/fluent-bit.conf"
    }
    
    provisioner "shell" {
        inline = [ "chown ${var.username}:${var.username} /home/${var.username}/.ssh/authorized_keys" ]
    }
}