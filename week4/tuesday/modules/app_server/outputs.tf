output "public_ip" {
  description = "Public IP adress of the instance"
  value = google_compute_instance.this.network_interface[0].access_config[0].nat_ip
}
output "instance_name" {
  description = "Name of the compute instance"
  value       = google_compute_instance.this.name
}

output "instance_zone" {
  description = "Zone where the instance is running"
  value       = google_compute_instance.this.zone
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/kijanikiosk-key ${var.ssh_user}@${google_compute_instance.this.network_interface[0].access_config[0].nat_ip}"
}