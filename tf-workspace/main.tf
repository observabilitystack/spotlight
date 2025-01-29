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
  size      = 64
  server_id = hcloud_server.this.id
  automount = true
  format    = "ext4"

  lifecycle {
    prevent_destroy = true
  }
}

resource "hcloud_floating_ip" "this" {
  type = "ipv4"
}

resource "hcloud_floating_ip_assignment" "this" {
  floating_ip_id = hcloud_floating_ip.this.id
  server_id      = hcloud_server.this.id
}

resource "hcloud_server" "this" {
  name        = random_id.this.hex
  image       = "debian-12"
  server_type = var.instance_size
  location    = var.datacenter
  ssh_keys    = [hcloud_ssh_key.root.name]
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

  dynamic "part" {
    for_each = ["default.yaml", "hetzner-floating-ip.yaml", "node-exporter.yaml", "docker.yaml", "spot-price-exporter.yaml", "spotlight-configuration.yaml", "prometheus.yaml", "grafana.yaml", "traefik-tls.yaml", "verify-services.yaml"]

    content {
      content_type = "text/cloud-config"
      content = templatefile("${path.module}/manifests/${part.value}",
        {
          terraform_ssh_public_key = tls_private_key.terraform.public_key_openssh,
          floating_ip              = hcloud_floating_ip.this.ip_address
          aws_access_key           = var.spotlight_aws_access_key,
          aws_secret_access_key    = var.spotlight_aws_secret_access_key,
          grafana_admin_password   = random_password.grafana_admin.result,
          grafana_domain           = "spotlight.o11y.cool",
          services                 = toset(["docker", "grafana", "prometheus", "traefik"])
        }
      )
    }
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
    port      = "22"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

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
