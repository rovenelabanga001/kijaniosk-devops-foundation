locals {
  ssh_public_key = file(pathexpand(var.ssh_pub_key_file))
}

resource "google_compute_instance" "this" {
  name         = "kijanikiosk-${var.name}-${var.environment}"
  machine_type = var.machine_type
  zone         = var.zone
  project      = var.project_id

  tags = ["kijanikiosk", "http-server", "ssh-server"]

  boot_disk {
    initialize_params {
      image = var.image
      size  = 10
      type  = "pd-standard"
    }
  }

  network_interface {
    network = "default"
    access_config {
      # Ephemeral public IP assigned automatically
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${local.ssh_public_key}"
  }

  labels = {
    environment = var.environment
    service     = var.name
    managed_by  = "terraform"
  }
}