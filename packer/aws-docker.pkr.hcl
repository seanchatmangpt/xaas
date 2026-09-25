# in packer/aws-docker.pkr.hcl

packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "base" {
  ami_name      = "amazon-linux-docker_{{timestamp}}"
  instance_type = "t2.micro"

  source_ami_filter {
    filters = {
      name         = "al2023-ami-2023*"
      architecture = "x86_64"
    }
    most_recent = true
    owners      = ["amazon"]
  }
  ssh_username = "ec2-user"
  ami_regions  = var.ami_regions
}

build {
  sources = ["source.amazon-ebs.base"]

  provisioner "shell" {
    inline = ["sudo dnf update -y cloud-init"]
  }

  provisioner "shell" {
    script = "setup.sh"
    # run script after cloud-init finishes to avoid race conditions
    execute_command = "cloud-init status --wait && sudo -E sh '{{ .Path }}'"
  }
}
