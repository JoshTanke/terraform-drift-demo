


terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  backend "gcs" {
    bucket = "infra-new-state"
    prefix = "drift-testing"
  }
}

provider "google" {
  project = "launchflow-services-dev"
  region  = "us-central1"
}

# Storage bucket - easy to modify labels and lifecycle rules in console
resource "google_storage_bucket" "drift_test_bucket" {
  name          = "drift-test-bucket-${random_id.bucket_suffix.hex}"
  location      = "US-CENTRAL1"
  storage_class = "NEARLINE"
  project       = "launchflow-services-dev"
  requester_pays = true
  
  labels = {
    environment = "dev"
    team        = "platform"
    foo         = "baz"
  }

  versioning {
    enabled = true
  }

  # Rule 1: Delete objects after 30 days (existing)
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  # Rule 2: Transition objects to COLDLINE after 60 days
  lifecycle_rule {
    condition {
      age = 60
      matches_storage_class = ["NEARLINE"]
    }
    action {
      type = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  # Rule 3: Delete old versions after 7 days
  lifecycle_rule {
    condition {
      age = 7
      with_state = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  # Rule 4: Delete objects with "temp-" prefix after 3 days
  lifecycle_rule {
    condition {
      age = 3
      matches_prefix = ["temp-"]
    }
    action {
      type = "Delete"
    }
  }

  force_destroy = true
}

# Static IP address - easy to change description and labels in console
resource "google_compute_address" "drift_test_ip" {
  name        = "drift-test-static-ip"
  region      = "us-central1"
  description = "Static IP for drift testing"
  project     = "launchflow-services-dev"
  
  labels = {
    environment = "dev"
    some        = "value"
  }
}

# Secret Manager secret - easy to modify labels and annotations in console
resource "google_secret_manager_secret" "drift_test_secret" {
  secret_id = "drift-test-secret"
  project   = "launchflow-services-dev"
  
  labels = {
    environment = "dev"
    purpose     = "drift-testing"
    sensitive   = "false"
  }

  annotations = {
    description = "Test secret for drift detection"
    owner       = "platform-team"
  }

  replication {
    auto {}
  }
}

# Random ID for unique bucket naming
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Output values for easy reference
output "bucket_name" {
  value = google_storage_bucket.drift_test_bucket.name
}

output "static_ip" {
  value = google_compute_address.drift_test_ip.address
}

output "secret_name" {
  value = google_secret_manager_secret.drift_test_secret.name
}
