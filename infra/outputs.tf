output "public_ip" {
  value = openstack_networking_floatingip_v2.build.address
}

output "ssh_config" {
  description = "Cole em ~/.ssh/config para entrar com `ssh hobbos-build`"
  value       = <<-EOT
    Host hobbos-build
      HostName ${openstack_networking_floatingip_v2.build.address}
      User ${var.ssh_user}
  EOT
}
