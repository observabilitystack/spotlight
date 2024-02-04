# ---------------------------------------------------------------------
# Create prometheus
# ---------------------------------------------------------------------
resource "random_id" "this" {
  prefix      = "spotlight-"
  byte_length = 2
  keepers = {
    cloud_init = sha256(data.cloudinit_config.this.rendered)
  }
}

resource "hcloud_volume" "this" {
  name      = "prometheus-spotlight-data"
  size      = 32
  server_id = hcloud_server.this.id
  automount = true
  format    = "ext4"
}

resource "hcloud_floating_ip" "this" {
  type      = "ipv4"
  server_id = hcloud_server.this.id
}

resource "hcloud_server" "this" {
  name        = random_id.this.hex
  image       = "debian-12"
  server_type = var.instance_size
  location    = var.datacenter
  ssh_keys    = [ hcloud_ssh_key.root.name ]
  user_data   = data.cloudinit_config.this.rendered

  labels = {
    service    = "spotlight"
    datacenter = var.datacenter
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait --long"
    ]

    connection {
      type        = "ssh"
      user        = "terraform"
      host        = self.ipv4_address
      private_key = tls_private_key.terraform.private_key_pem
    }
  }
}

resource "random_password" "grafana_admin" {
  length  = 32
  special = false
}

data "cloudinit_config" "this" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/manifests/default.yaml", {
      terraform_ssh_public_key = tls_private_key.terraform.public_key_openssh
    })
  }
  part {
    content_type = "text/cloud-config"
    content      = file("${path.module}/manifests/node-exporter.yaml")
  }
  part {
    content_type = "text/cloud-config"
    content = file("${path.module}/manifests/docker.yaml")
  }
  part {
    content_type = "text/cloud-config"
    content = file("${path.module}/manifests/traefik-tls.yaml")
  }
  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/manifests/spot-price-exporter.yaml", {
      aws_access_key        = var.spotlight_aws_access_key
      aws_secret_access_key = var.spotlight_aws_secret_access_key
    })
  }
  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/manifests/spotlight-configuration.yaml", {
      grafana_admin_password = random_password.grafana_admin.result
    })
  }
  part {
    content_type = "text/cloud-config"
    content = file("${path.module}/manifests/prometheus.yaml")
  }
  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/manifests/grafana.yaml", {
      grafana_domain = "spotlight.o11ystack.org"
    })
  }
  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/manifests/verify-services.yaml", {
      services = toset(["docker", "grafana", "prometheus", "traefik"])
    })
  }
}

# ---------------------------------------------------------------------
# Open https and assign dns
# ---------------------------------------------------------------------
resource "hcloud_firewall" "this" {
  name = "public-spotlight"

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  apply_to {
    label_selector = "service=spotlight"
  }
}
