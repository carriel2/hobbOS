# VM de build do HobbOS: um Arch limpo com archiso, para rodar o mkarchiso.
# É descartável: o perfil vive no Git, e `tofu destroy` libera a quota quando não estiver em uso.

data "openstack_networking_network_v2" "external" {
  name     = var.external_network_name
  external = true
}

data "openstack_images_image_v2" "arch" {
  name        = var.image_name
  most_recent = true
}

resource "openstack_compute_keypair_v2" "admin" {
  name       = "${var.name}-admin"
  public_key = var.ssh_public_key
}

# ── rede ───────────────────────────────────────────────────────────────────

resource "openstack_networking_network_v2" "this" {
  name           = "${var.name}-net"
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "this" {
  name            = "${var.name}-subnet"
  network_id      = openstack_networking_network_v2.this.id
  cidr            = var.subnet_cidr
  ip_version      = 4
  dns_nameservers = var.dns_nameservers
}

resource "openstack_networking_router_v2" "this" {
  name                = "${var.name}-router"
  external_network_id = data.openstack_networking_network_v2.external.id
}

resource "openstack_networking_router_interface_v2" "this" {
  router_id = openstack_networking_router_v2.this.id
  subnet_id = openstack_networking_subnet_v2.this.id
}

# De fora, só SSH e só das redes de administração.
resource "openstack_networking_secgroup_v2" "build" {
  name        = "${var.name}-build"
  description = "VM de build do HobbOS"
}

resource "openstack_networking_secgroup_rule_v2" "ssh" {
  for_each = toset(var.admin_cidrs)

  security_group_id = openstack_networking_secgroup_v2.build.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = each.value
}

# ── VM ─────────────────────────────────────────────────────────────────────

resource "openstack_networking_port_v2" "build" {
  name               = "${var.name}-build"
  network_id         = openstack_networking_network_v2.this.id
  security_group_ids = [openstack_networking_secgroup_v2.build.id]

  fixed_ip {
    subnet_id  = openstack_networking_subnet_v2.this.id
    ip_address = cidrhost(var.subnet_cidr, 10)
  }
}

resource "openstack_compute_instance_v2" "build" {
  depends_on = [openstack_networking_router_interface_v2.this] # pacman precisa de saída para a internet

  name        = "${var.name}-build"
  flavor_name = var.flavor
  image_id    = data.openstack_images_image_v2.arch.id
  key_pair    = openstack_compute_keypair_v2.admin.name
  user_data   = file("${path.module}/cloud-init.yaml")

  network {
    port = openstack_networking_port_v2.build.id
  }

  block_device {
    uuid                  = data.openstack_images_image_v2.arch.id
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = var.volume_size_gb
    volume_type           = var.volume_type
    boot_index            = 0
    delete_on_termination = true
  }
}

resource "openstack_networking_floatingip_v2" "build" {
  pool = data.openstack_networking_network_v2.external.name
}

resource "openstack_networking_floatingip_associate_v2" "build" {
  depends_on  = [openstack_networking_router_interface_v2.this]
  floating_ip = openstack_networking_floatingip_v2.build.address
  port_id     = openstack_networking_port_v2.build.id
}
