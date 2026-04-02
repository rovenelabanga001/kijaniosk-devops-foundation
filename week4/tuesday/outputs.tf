output "api_server_public_ip" {
    description = "Public API adress for the Kijanikiosk API server"
    value = google_compute_instance.kk_api.network_interface[0].access_config[0].nat_ip
}

output "ssh_command" {
    description = "SSH command to connect to the API server"
    value = "ssh -i ~/.ssh/kijanikiosk-key ${var.ssh_user}@${google_compute_instance.kk_api.network_interface[0].access_config[0].nat_ip}"
  
}

output "instance_name" {
    description = "Name of the compute instance"
    value = google_compute_instance.kk_api.name
}

output "instance_zone" {
    description = "Zone where the instance is runninng"
    value = google_compute_instance.kk_api.zone
  
}