##-----------------------------------------------------------------------------
## Labels module called that will be used for naming and tags
##-----------------------------------------------------------------------------

module "labels" {
  source  = "clouddrove/labels/azure"
  version = "1.0.0"

  name          = var.name
  environment   = var.environment
  managedby     = var.managedby
  business_unit = var.business_unit
  label_order   = var.label_order
  repository    = var.repository
  extra_tags    = var.extra_tags
}

##-----------------------------------------------------------------------------
## Terraform resource for resource group.
## Azure automatically deletes any Resources nested within the Resource Group when a Resource Group is deleted.
##-----------------------------------------------------------------------------
resource "azurerm_resource_group" "default" {
  count    = var.enabled ? 1 : 0
  name     = format("%s-resource-group", module.labels.id)
  location = var.location
  # Error 1: Missing tags - Checkov will detect missing tags (CKV_AZURE_1)
  # tags     = module.labels.tags

  timeouts {
    create = var.create
    read   = var.read
    update = var.update
    delete = var.delete
  }
}

##--------------------------------------------------------------------------------
## Manages a Management Lock which is scoped to a Subscription, Resource Group or Resource.
##--------------------------------------------------------------------------------
resource "azurerm_management_lock" "resource-group-level" {
  count      = var.enabled && var.resource_lock_enabled ? 1 : 0
  name       = format("%s-rg-lock", var.lock_level)
  scope      = azurerm_resource_group.default[0].id
  # Error 2: Invalid lock level - should be either "CanNotDelete" or "ReadOnly"
  lock_level = "InvalidLockLevel"  # This will cause Checkov to detect an invalid lock level
  notes      = var.notes
}

##--------------------------------------------------------------------------------
## Adding a storage account with security issues
##--------------------------------------------------------------------------------
resource "azurerm_storage_account" "example" {
  name                     = "examplestorage"
  resource_group_name      = azurerm_resource_group.default[0].name
  location                 = azurerm_resource_group.default[0].location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  # Error 3: Missing network rules (CKV_AZURE_33)
  # network_rules not defined
  
  # Error 4: Disabled HTTPS traffic only (CKV_AZURE_3)
  enable_https_traffic_only = false
  
  # Error 5: Disabled secure transfer (redundant with above but different check)
  min_tls_version = "TLS1_0"  # Should be TLS1_2
  
  # Error 6: Missing encryption (CKV2_AZURE_1, CKV2_AZURE_18)
  # No customer-managed keys defined
}

##--------------------------------------------------------------------------------
## Adding a Key Vault with security issues
##--------------------------------------------------------------------------------
resource "azurerm_key_vault" "example" {
  name                        = "examplekeyvault"
  location                    = azurerm_resource_group.default[0].location
  resource_group_name         = azurerm_resource_group.default[0].name
  enabled_for_disk_encryption = false  # Error 7: Should be true (CKV_AZURE_42)
  tenant_id                   = "00000000-0000-0000-0000-000000000000"
  soft_delete_retention_days  = 7      # Error 8: Too low, should be 90+ (CKV_AZURE_42)
  purge_protection_enabled    = false  # Error 9: Should be true (CKV_AZURE_110)
  
  sku_name = "standard"
  
  # Error 10: Public network access enabled (CKV_AZURE_109)
  public_network_access_enabled = true
  
  # Error 11: No network ACLs defined
  # network_acls not defined
}
