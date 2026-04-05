output "server_ips" {
  description = "Public IP addresses of all servers"
  value       = { for k, v in module.app_servers : k => v.public_ip }
}

output "ssh_commands" {
  description = "SSH commands for all servers"
  value       = { for k, v in module.app_servers : k => v.ssh_command }
}

output "api_ip" {
  description = "Public IP of the API server"
  value       = module.app_servers["api"].public_ip
}

output "payments_ip" {
  description = "Public IP of the payments server"
  value       = module.app_servers["payments"].public_ip
}

output "logs_ip" {
  description = "Public IP of the logs server"
  value       = module.app_servers["logs"].public_ip
}