terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.80.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# 1. Resource Group
resource "azurerm_resource_group" "res-1" {
  location = "mexicocentral"
  name     = "App-RG-Lab02"
}

# 2. SSH Public Key
resource "azurerm_ssh_public_key" "res-1" {
  location            = azurerm_resource_group.res-1.location
  name                = "lab-ssh-key"
  public_key          = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDdoup8bFb8/wII6oq8AJaygs9bK8q/+gDmavHwwB8bLBe3c946HBRfnxH6yei+nM0SGv/HyPoGtIR5VKgRWpWem1Lldfda4Kqp0r9SeEE9p3pS6Wlm33GwFv5XlaqjZfNO3AykpqfQVArZV6FOuqEJyP+42bjiQdgO1yme54zLtTp4k6PAATu3JTa9yMjP5VJ49ytuRNdZ/EYZ53+RcNbXdZChPe2J2noRjQnDIziq4HXAf/hCmEnCLWnVOkg6tEkzXAFpPVv9fT23m4mobzRmaQlOpRf5PYbMgBCjT5VY9B/ElC0vyEVknd/UDkIBX4EIoFOMnSSQJ9MLzFyt1NRmO2rmRX2tgvngDqCkJXgAbbSejDni0TMLgRH9mPGaGQ0lF5JCsOG4vjEUnbbis4tyjskjk4VTNvX7wnEgQry0og2OG1EoE55GJuFQrbnyh6Kc3fkBP5cczlCcTmlcHwd+yEV0Y9jgiX0Nv3jhOumXdlK7pRgi42bN2nV2hcSe0R0= generated-by-azure"
  resource_group_name = azurerm_resource_group.res-1.name
}

# 3. Virtual Network & Subnets (Standalone configuration to prevent inline/standalone conflicts)
resource "azurerm_virtual_network" "res-1" {
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.res-1.location
  name                = "vnet-lab23"
  resource_group_name = azurerm_resource_group.res-1.name
}

resource "azurerm_subnet" "web" {
  name                 = "web-subnet"
  resource_group_name  = azurerm_resource_group.res-1.name
  virtual_network_name = azurerm_virtual_network.res-1.name
  address_prefixes     = ["10.0.1.0/24"]

  # Force Terraform to wait for the VNet to exist first
  depends_on = [azurerm_virtual_network.res-1]
}

resource "azurerm_subnet" "db" {
  name                 = "db-subnet"
  resource_group_name  = azurerm_resource_group.res-1.name
  virtual_network_name = azurerm_virtual_network.res-1.name
  address_prefixes     = ["10.0.2.0/24"]

  # Force Terraform to wait for the VNet to exist first
  depends_on = [azurerm_virtual_network.res-1]
}

# 4. Network Security Groups (Cleaned using standalone rules to prevent overlaps)
resource "azurerm_network_security_group" "db" {
  location            = azurerm_resource_group.res-1.location
  name                = "vm-db-01-nsg"
  resource_group_name = azurerm_resource_group.res-1.name
}

resource "azurerm_network_security_rule" "db_allow_web" {
  name                        = "Allow-Web-Subnet"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "10.0.1.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.res-1.name
  network_security_group_name = azurerm_network_security_group.db.name
}

resource "azurerm_network_security_rule" "db_allow_ssh" {
  name                        = "SSH"
  priority                    = 300
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.res-1.name
  network_security_group_name = azurerm_network_security_group.db.name
}

resource "azurerm_network_security_group" "web" {
  location            = azurerm_resource_group.res-1.location
  name                = "vm-web-01-nsg"
  resource_group_name = azurerm_resource_group.res-1.name
}

resource "azurerm_network_security_rule" "web_allow_ssh" {
  name                        = "SSH"
  priority                    = 320
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.res-1.name
  network_security_group_name = azurerm_network_security_group.web.name
}

resource "azurerm_network_security_rule" "web_allow_http" {
  name                        = "HTTP"
  priority                    = 300
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.res-1.name
  network_security_group_name = azurerm_network_security_group.web.name
}

# 5. Public IP for Web VM
resource "azurerm_public_ip" "web" {
  allocation_method   = "Static"
  location            = azurerm_resource_group.res-1.location
  name                = "vm-web-01-ip"
  resource_group_name = azurerm_resource_group.res-1.name
}

# 6. Network Interfaces
resource "azurerm_network_interface" "db" {
  location            = azurerm_resource_group.res-1.location
  name                = "vm-db-01759"
  resource_group_name = azurerm_resource_group.res-1.name

  ip_configuration {
    name                          = "ipconfig1"
    primary                       = true
    private_ip_address            = "10.0.2.4"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.db.id
  }
}

resource "azurerm_network_interface_security_group_association" "db" {
  network_interface_id      = azurerm_network_interface.db.id
  network_security_group_id = azurerm_network_security_group.db.id
}

resource "azurerm_network_interface" "web" {
  location            = azurerm_resource_group.res-1.location
  name                = "vm-web-01682"
  resource_group_name = azurerm_resource_group.res-1.name

  ip_configuration {
    name                          = "ipconfig1"
    primary                       = true
    private_ip_address            = "10.0.1.4"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.web.id
    subnet_id                     = azurerm_subnet.web.id
  }
}

resource "azurerm_network_interface_security_group_association" "web" {
  network_interface_id      = azurerm_network_interface.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}

# 7. Virtual Machines (Provisioned from image cleanly, dropping stale static os_managed_disk_ids)
resource "azurerm_linux_virtual_machine" "db" {
  name                              = "vm-db-01"
  resource_group_name               = azurerm_resource_group.res-1.name
  location                          = azurerm_resource_group.res-1.location
  size                              = "Standard_B2ats_v2"
  admin_username                    = "azureuser"
  network_interface_ids             = [azurerm_network_interface.db.id]
  disable_password_authentication   = true
  secure_boot_enabled               = true
  vtpm_enabled                      = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = azurerm_ssh_public_key.res-1.public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "ubuntu-pro"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "web" {
  name                              = "vm-web-01"
  resource_group_name               = azurerm_resource_group.res-1.name
  location                          = azurerm_resource_group.res-1.location
  size                              = "Standard_B2ats_v2"
  admin_username                    = "azureuser"
  network_interface_ids             = [azurerm_network_interface.web.id]
  disable_password_authentication   = true
  secure_boot_enabled               = true
  vtpm_enabled                      = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = azurerm_ssh_public_key.res-1.public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "ubuntu-pro"
    version   = "latest"
  }
}