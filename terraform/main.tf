terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

variable "project_id" {
  description = "GCP project ID (create a fresh one — don't reuse a project tied to anything else)"
  type        = string
}

variable "ssh_source_ranges" {
  description = "CIDR ranges allowed to reach port 22. Lock this to your own egress IP(s), not 0.0.0.0/0."
  type        = list(string)
}

variable "repo_url" {
  description = "Git URL this VM clones at boot to get docker/Dockerfile + docker-compose.yml (e.g. https://github.com/moquito64/tailwag-derper.git)"
  type        = string
}

# us-west1 / us-central1 / us-east1 are the only Always Free e2-micro
# regions. Everything below is pinned to us-central1 — change all
# three (provider, address, instance) together if you move regions.
provider "google" {
  project = var.project_id
  region  = "us-central1"
  zone    = "us-central1-a"
}

resource "google_compute_address" "derper_ip" {
  name   = "tailwag-derper-ip"
  region = "us-central1"
  # Free while attached to a running instance. Starts billing the
  # moment it's reserved-but-unattached or attached to a stopped VM —
  # keep this instance always-on, don't stop it to save cost.
}

resource "google_compute_firewall" "derper" {
  name    = "allow-tailwag-derper"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
  allow {
    protocol = "udp"
    ports    = ["3478"] # STUN
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["tailwag-derper"]
}

resource "google_compute_firewall" "ssh" {
  name    = "allow-tailwag-derper-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = var.ssh_source_ranges
  target_tags   = ["tailwag-derper"]
}

resource "google_compute_instance" "derper" {
  name         = "tailwag-derper"
  machine_type = "e2-micro" # Always Free eligible in the 3 regions above
  zone         = "us-central1-a"
  tags         = ["tailwag-derper"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 30 # GB — matches the free 30GB pd-standard allowance
      type  = "pd-standard"
    }
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.derper_ip.address
    }
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  metadata_startup_script = templatefile("${path.module}/startup.sh.tftpl", {
    repo_url = var.repo_url
  })
}

output "derper_ip" {
  value       = google_compute_address.derper_ip.address
  description = "Point your derper hostname's A/AAAA record at this."
}
