variable "azure_public_ssh_key" {
  description = "Path to the Azure public SSH key"
  type        = string
  default     = "/C/devops/azure/azure_keys/ansible-server_key.pem"
}