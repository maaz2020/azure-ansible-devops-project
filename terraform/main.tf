# terraform {
#   required_providers {
#     azurerm = {
#       source  = "hashicorp/azurerm"
#       version = ">=3.0.0"
#     }
#   }
# }

# provider "azurerm" {
#   features {}
# }
# Resource Group
resource "azurerm_resource_group" "microservice" {
  name     = "microservice-resources"
  location = "West US"
}

# Virtual Network
resource "azurerm_virtual_network" "microservice_vnet" {
  name                = "microserviceVNet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.microservice.location
  resource_group_name = azurerm_resource_group.microservice.name
}

# Subnet
resource "azurerm_subnet" "microservice_subnet" {
  name                 = "microserviceSubnet"
  resource_group_name  = azurerm_resource_group.microservice.name
  virtual_network_name = azurerm_virtual_network.microservice_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group
resource "azurerm_network_security_group" "http_server_sg" {
  name                = "httpServerSG"
  location            = azurerm_resource_group.microservice.location
  resource_group_name = azurerm_resource_group.microservice.name

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSSH"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowAllOutbound"
    priority                   = 1003
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Network Interface
resource "azurerm_network_interface" "http_server_nic" {
  count               = 2
  name                = "httpServerNIC-${count.index}"
  location            = azurerm_resource_group.microservice.location
  resource_group_name = azurerm_resource_group.microservice.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.microservice_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.microservice[count.index].id
  }
}


# Associate the Network Security Group with each Network Interface
resource "azurerm_network_interface_security_group_association" "http_server_sg_association" {
  count                     = 2
  network_interface_id      = azurerm_network_interface.http_server_nic[count.index].id
  network_security_group_id = azurerm_network_security_group.http_server_sg.id
}

# public_ip
resource "azurerm_public_ip" "microservice" {
  count               = 2
  name                = "acceptanceTestPublicIp-${count.index}"
  resource_group_name = azurerm_resource_group.microservice.name
  location            = azurerm_resource_group.microservice.location
  allocation_method   = "Static"
}


# Virtual Machine Instances
resource "azurerm_linux_virtual_machine" "http_server" {
  count               = 2
  name                = "httpServerVM-${count.index}"
  resource_group_name = azurerm_resource_group.microservice.name
  location            = azurerm_resource_group.microservice.location
  size                = "Standard_B2ms" # Equivalent to t2.micro in AWS
  admin_username      = "adminuser"
  # admin_password                  = "Maaz@1234"
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.http_server_nic[count.index].id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/azurekey_rsa.pub") # Replace with the correct path to the public key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

}

