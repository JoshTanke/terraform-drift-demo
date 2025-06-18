
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

  # Rule 1: Set storage class to ARCHIVE for NEARLINE objects immediately
  lifecycle_rule {
    condition {
      age = 0
      matches_storage_class = ["NEARLINE"]
    }
    action {
      type = "SetStorageClass"
      storage_class = "ARCHIVE"
    }
  }

  # Rule 2: Delete archived objects after 7 days
  lifecycle_rule {
    condition {
      age = 7
      with_state = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  # Rule 3: Delete objects with "temp-" prefix after 3 days
  lifecycle_rule {
    condition {
      age = 3
      with_state = "ANY"
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

# Compute disk - easy to modify labels and description in console
resource "google_compute_disk" "drift_test_disk" {
  name        = "drift-test-disk"
  type        = "pd-standard"
  zone        = "us-central1-a"
  size        = 10
  description = "Test disk for drift detection"
  project     = "launchflow-services-dev"
  
  labels = {
    environment = "dev"
    purpose     = "drift-testing"
    size        = "small"
  }
}

# Pub/Sub topic - easy to modify labels in console
resource "google_pubsub_topic" "drift_test_topic" {
  name    = "drift-test-topic"
  project = "launchflow-services-dev"
  
  labels = {
    environment = "dev"
    purpose     = "drift-testing"
    team        = "platform"
  }
  
  message_retention_duration = "86400s"
}

# Cloud Scheduler job - easy to modify description and schedule in console
resource "google_cloud_scheduler_job" "drift_test_job" {
  name        = "drift-test-job"
  description = "Test job for drift detection"
  schedule    = "0 9 * * 1"
  time_zone   = "America/New_York"
  region      = "us-central1"
  project     = "launchflow-services-dev"
  paused      = true
  
  pubsub_target {
    topic_name = google_pubsub_topic.drift_test_topic.id
    data       = base64encode("Hello from drift test job!")
    
    attributes = {
      environment = "dev"
      purpose     = "drift-testing"
    }
  }
  
  retry_config {
    retry_count = 3
    max_retry_duration = "60s"
    min_backoff_duration = "5s"
    max_backoff_duration = "30s"
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

output "disk_name" {
  value = google_compute_disk.drift_test_disk.name
}

output "topic_name" {
  value = google_pubsub_topic.drift_test_topic.name
}

output "scheduler_job_name" {
  value = google_cloud_scheduler_job.drift_test_job.name
}
