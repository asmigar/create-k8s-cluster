output "ssh_command_master_node" {
  value       = <<-SSHCOMMAND
  ssh ec2-user@${aws_instance.master.public_dns}
  SSHCOMMAND
  description = "ssh command for connecting to the master node"
}

output "ssh_command_worker_nodes" {
  value       = <<-SSHCOMMAND
  %{for dns in aws_instance.worker[*].public_dns}
  ssh ec2-user@${dns}
  %{endfor}
  SSHCOMMAND
  description = "ssh command for connect to the worker node"
}