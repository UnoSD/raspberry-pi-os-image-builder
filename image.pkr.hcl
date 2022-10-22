variable "image_url"           { type = string }
variable "image_checksum"      { type = string }
variable "ssh_public_key_path" { type = string }
variable "username"            { type = string }
variable "hostname"            { type = string }
variable "timezone"            { type = string }

variable "wpa_supplicant_path" {
    type    = string 
    default = ""
}

variable "ip" {
    type    = string 
    default = ""
}

variable "subnet" {
    type    = string 
    default = ""
}

variable "router" {
    type    = string 
    default = ""
}

source "arm-image" "raspbian" {
    iso_url      = "${var.image_url}"
    iso_checksum = "${var.image_checksum}"
}

build {
    sources = [ "source.arm-image.raspbian" ]

    provisioner "shell" {
        environment_vars = [ 
            "USERNAME=${var.username}",
            "IP=${var.ip}",
            "SUBNET=${var.subnet}",
            "ROUTER=${var.router}",
            "HOSTNAME=${var.hostname}",
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
    
    provisioner "shell" {
        inline = [ "chown ${var.username}:${var.username} /home/${var.username}/.ssh/authorized_keys" ]
    }
}