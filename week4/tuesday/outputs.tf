output "server_ips" {
    description = "Public API addresses for all servers"
    value = {for k, v in module.app_servers : k => v.public_ip}
}

output "ssh_commands" {
    description = "SSH commands for all servers"
    value = {for k, v in module.app_servers : k => v.ssh_command}
}

# output "instance_name" {
#     description = "Name of the compute instance"
#     value = google_compute_instance.kk_api.name
# }

# output "instance_zone" {
#     description = "Zone where the instance is runninng"
#     value = google_compute_instance.kk_api.zone
  
# }